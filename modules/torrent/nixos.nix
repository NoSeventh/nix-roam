# modules/torrent/nixos.nix
#
# 种子盒层：qBittorrent-nox（WebUI）+ FakeHTTP（NFQUEUE 把 BT 上传 TCP 伪装成 HTTP，
# 绕过运营商对上传流量的 QoS 识别限速）。系统级专属：需要内核 nfnetlink_queue 与
# CAP_NET_ADMIN，无用户级实现。
#
# FakeHTTP 上游默认自己装 nft 规则并对整机全部 TCP 连接做伪装；本层改为 `-f` 跳过
# 自动规则、复刻其表结构（src/ipv4nft.c，表名换成 torrent-fakehttp），只把
# qBittorrent 的流量送进队列：
#   - qBittorrent 监听 btPort（入站连接）；出站连接源端口限制在
#     [btPort+1, btPort+poolSize]（Session\OutgoingPortsMin/Max，qBittorrent 5.3
#     源码实证键名），nft 据此圈定仅 BT 流量；
#   - postrouting 匹配 `tcp sport <端口池>`（出站连接握手 + 入站连接的回包）、
#     prerouting 匹配 `tcp dport btPort`（入站连接握手，兼作 TTL 跳数估计来源）；
#   - 其余复刻上游：内网目的/来源放行、SYN + 前 2-4 个 ACK 入队、fwmark 0x8000
#     旁路（FakeHTTP 自产的伪造包不再入队）、queue bypass（进程不在时直接放行，
#     规则不黑洞流量）。
# 仅 IPv4：WSL NAT 模式无 v6 出口；若将来启用镜像网络 v6，需补 ip6 表与 -6。
# 规则随本服务启停（ExecStartPre/ExecStopPost），不占用 NixOS 全局 nftables
# ruleset，与防火墙后端互不干扰。
{ pkgs, lib, ... }:

let
  # qBittorrent 入站监听端口（WebUI 之外唯一对外 TCP 端口）
  btPort = 51413;
  # 出站连接源端口池大小：并发对外连接各占一个源端口，池过小会限制出站并发
  poolSize = 100;
  # FakeHTTP 默认 NFQUEUE 编号（-n）与旁路 fwmark（-m/-x，0x8000）
  queueNum = 512;
  fwmark = 32768;
  # 伪装域名：HTTP 方向 (-h) 与 HTTPS 方向 (-e) 各报一个普通高流量站点
  fakeHost = "www.baidu.com";

  portPool = "${toString btPort}-${toString (btPort + poolSize)}";

  # 复刻 FakeHTTP src/ipv4nft.c 的表结构，仅把队列条件收窄到 qBittorrent 端口
  fakehttpRules = pkgs.writeText "torrent-fakehttp.nft" ''
    table ip torrent-fakehttp {
        chain fh_prerouting {
            type filter hook prerouting priority mangle - 5; policy accept;
            ip saddr 0.0.0.0/8      return;
            ip saddr 10.0.0.0/8     return;
            ip saddr 100.64.0.0/10  return;
            ip saddr 127.0.0.0/8    return;
            ip saddr 169.254.0.0/16 return;
            ip saddr 172.16.0.0/12  return;
            ip saddr 192.168.0.0/16 return;
            ip saddr 224.0.0.0/3    return;
            meta mark and ${toString fwmark} == ${toString fwmark} return;
            tcp dport ${toString btPort} tcp flags & (syn | fin | rst) == syn queue num ${toString queueNum} bypass;
            tcp dport ${toString btPort} tcp flags & (syn | ack | fin | rst) == ack ct packets 2-4 queue num ${toString queueNum} bypass;
        }
        chain fh_postrouting {
            type filter hook postrouting priority srcnat + 5; policy accept;
            ip daddr 0.0.0.0/8      return;
            ip daddr 10.0.0.0/8     return;
            ip daddr 100.64.0.0/10  return;
            ip daddr 127.0.0.0/8    return;
            ip daddr 169.254.0.0/16 return;
            ip daddr 172.16.0.0/12  return;
            ip daddr 192.168.0.0/16 return;
            ip daddr 224.0.0.0/3    return;
            meta mark and ${toString fwmark} == ${toString fwmark} return;
            tcp sport ${portPool} tcp flags & (syn | fin | rst) == syn queue num ${toString queueNum} bypass;
            tcp sport ${portPool} tcp flags & (syn | ack | fin | rst) == ack ct packets 2-4 queue num ${toString queueNum} bypass;
        }
    }
  '';
in
{
  # ============================================
  # 1. qBittorrent-nox（WebUI :8080，系统用户 qbittorrent）
  # ============================================
  services.qbittorrent = {
    enable = true;
    openFirewall = true; # 8080 + btPort；WSL NAT 下无公网入站，桌面 NixOS 上也只开这两个口
    webuiPort = 8080;
    torrentingPort = btPort;
    serverConfig = {
      # 无头运行必须先接受法律声明
      LegalNotice.Accepted = true;
      BitTorrent = {
        # 出站连接源端口池：nft 规则据此圈定仅 BT 流量进 NFQUEUE
        "Session\\OutgoingPortsMin" = btPort + 1;
        "Session\\OutgoingPortsMax" = btPort + poolSize;
      };
      Preferences.WebUI = {
        Username = "admin";
        # 密码不入库：首启用 journalctl -u qbittorrent 里的随机临时密码登录 WebUI。
        # 注意 serverConfig 非空时每次重启都会重装 qBittorrent.conf（上游模块行为），
        # WebUI 里改的设置会被覆盖；要固定密码就转成 Password_PBKDF2 填进来。
      };
    };
  };

  # ============================================
  # 2. NFQUEUE 内核模块
  # ============================================
  # WSL 宿主内核为模块化构建（xt_NFQUEUE=m），模块由 WSL 以 overlay 挂载到
  # /lib/modules/<uname -r>，NixOS-WSL 内 systemd-modules-load 可正常 modprobe。
  boot.kernelModules = [ "nfnetlink_queue" "xt_NFQUEUE" ];

  # ============================================
  # 3. FakeHTTP：只伪装 qBittorrent 的上传 TCP
  # ============================================
  systemd.services.fakehttp = {
    description = "FakeHTTP: obfuscate qBittorrent TCP as HTTP (anti ISP upload throttling)";
    documentation = [ "https://github.com/MikeWang000000/FakeHTTP" ];
    wants = [ "network-online.target" ];
    after = [
      "network-online.target"
      "systemd-modules-load.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      # -f 跳过上游自动装的全局规则（本单元自管 torrent-fakehttp 表）；
      # -a 满足上游必填的接口参数（-f 时仅用于取源地址信息）；
      # -4 仅 IPv4；-y 50 按估计跳数的 50% 动态设定伪造包 TTL
      ExecStart = "${lib.getExe pkgs.fakehttp} -f -4 -a -y 50 -h ${fakeHost} -e ${fakeHost}";
      ExecStartPre = [
        # 幂等：旧表先删（首次启动时不存在，忽略失败）
        "-${pkgs.nftables}/bin/nft delete table ip torrent-fakehttp"
        "${pkgs.nftables}/bin/nft -f ${fakehttpRules}"
      ];
      ExecStopPost = "-${pkgs.nftables}/bin/nft delete table ip torrent-fakehttp";
      # NFQUEUE 绑定与 SO_MARK 需 CAP_NET_ADMIN，伪造用原始套接字需 CAP_NET_RAW
      AmbientCapabilities = [
        "CAP_NET_ADMIN"
        "CAP_NET_RAW"
      ];
      CapabilityBoundingSet = [
        "CAP_NET_ADMIN"
        "CAP_NET_RAW"
      ];
      NoNewPrivileges = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ProtectClock = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelTunables = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_NETLINK"
        "AF_UNIX"
      ];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      LockPersonality = true;
      SystemCallArchitectures = "native";
      Restart = "on-failure";
      RestartSec = "3s";
    };
  };
}
