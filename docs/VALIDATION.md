# 验证记录（Validation boundaries）

按日期记录每次改动实际验证到的边界（新 → 旧）。**状态只反映记录当时**，不代表当前提交已重新构建；具体验证环境（发行版 / 主机）以各条为准。

判断标准与常用手法：

- 对 Nix 改动：解析编辑过的文件 → 求值受影响的选项 / 派生 → 构建对应目标。不把「求值通过」当「构建通过」，不把「构建通过」当「激活通过」，也不把当前主机上找到的命令当作另一目标包内容的证据。
- 「纯重构」用五输出 drvPath 前后对比验证（干净树 vs 干净树）：`nix eval --raw .#<target>.drvPath`。注意 HM 侧 `programs.*` 子选项「显式设置为空值」与「未设置」可能生成不同文本（曾见于 `programs.bash.initExtra`：空串会多出一个换行），布尔注入必须用属性集级 `lib.optionalAttrs` 而非字符串级 `lib.optionalString`。
- 对纯文档改动：检查源一致性、本地链接、被删路径的引用与 `git diff --check`，无需重建或激活。

## 2026-09-24 单用户安装激活后 nix 不在 PATH（ArchLinux-WSL 首次 single 全程安装，本机 ArchLinux-WSL）

起因：ArchLinux-WSL（裸机、原本无 xuqihao 用户）经 bootstrap 建号 + `NIX_INSTALL_MODE=single` 七步全程完成安装并激活（当日 18:34–18:50，gen 1），激活本身成功，但此后任何新登录 shell 都找不到 `nix`。根因：单用户安装的 PATH 挂钩由官方安装器写进用户 dotfile（`~/.bash_profile` 尾行 source `~/.nix-profile/etc/profile.d/nix.sh`），而 HM 激活把 bash 登录链三件套（`.bash_profile`/`.profile`/`.bashrc`）整体替换为 store symlink，原文件轮转入 `.bash_profile.backup`/`.bashrc.bak-*`；HM 侧 `home.sessionPath`（common.nix）却不含 `~/.nix-profile/bin`。多用户安装不受影响（钩子在系统侧 `/etc/profile.d/nix-daemon.sh`，经 `/etc/profile` 恒先于用户 dotfile 加载）——single 模式特有缺口；bootstrap 运行全程无感，因为脚本会话继承的是安装时已 source 的旧 dotfile 环境。

改动：`home/standalone-linux.nix` 显式补 `home.sessionPath = [ "${homeDirectory}/.nix-profile/bin" ]`（listOf 合并与 common.nix 五条拼接；多用户机上与 nix-daemon.sh 注入重复无害；NixOS 模式不导入本文件不受影响，彼处无 `~/.nix-profile`）。`bootstrap/linux.sh` 7/7 之后新增 fail-loud 自检：`env -i` 干净环境起 `/bin/bash -lc` 验证 `command -v nix`，失败即报错退出并指向 sessionPath（zsh/fish 的 rc 追加段仅交互会话生效，注释中明确不在该检查范围）。

验证（本机 ArchLinux-WSL / WSL2 / 单用户 Nix 2.35.2，standalone `.#x86_64-linux`）：`bash -n` 与 `nix-instantiate --parse` 通过；`nix build --no-link .#homeConfigurations.x86_64-linux.activationPackage` 构建通过（闭包全缓存，仅重出 profile/activation/files/hm-putter/generation 五个派生）；`home-manager switch` 激活 gen 2（9va1j13…）exit 0；干净登录 shell（`env -i … /bin/bash -lc`）实测修复前复现 `NO-NIX-IN-PATH`、修复后 `nix`→`~/.nix-profile/bin/nix`（2.35.2）且 `home-manager` 同目录可用；交互登录 shell `type -t hms` = function（hms 定义在 `.bashrc` 交互守卫之后，非交互 shell 不可见属预期）；新 `hm-session-vars.sh` 的 `export PATH` 末位含 `~/.nix-profile/bin`；bootstrap 自检代码块原样抽出复跑 PASS。

未验证：aarch64-linux 输出（同模块，需 ARM 机）；自检在真实失败场景下的触发（仅正向复跑）；bootstrap 七步全程带新自检的重跑（本轮机器已装好，脚本幂等重跑属用户侧动作）；darwin 侧同类问题是否存在（macOS 安装器钩子在系统级 `/etc/zshrc`，理论不受影响，且 darwin.sh 从未实机运行）；CI 在本批提交上的运行。

## 2026-09-24 cachix 社区缓存补入缓存列表（Fedora 44 / WSL2 standalone，本机）

起因：`hms` 在本日 `update flake`（c2e40c3，15:28）后失败——`home/nixvim.nix` 启用的 `rainbow-delimiters` 要 `vimPlugins.rainbow-delimiters-nvim` v0.12.0，其源码 FOD 由 `fetchgit` 从 gitlab.com 取；本机网络下 `getent hosts gitlab.com` 只给被污染的 Cloudflare IPv6（2606:4700:90:…），`git ls-remote` 40s 无响应，构建退化为 reset + 两次 300s 超时后失败，级联 `vimplugin → neovim → nixvim → home-manager-path → home-manager-generation`。查因：该插件在 nixpkgs 中 `meta.license = unfree` → `meta.hydraPlatforms = [ ]`，官方 Hydra 不构建，源码与产物都不在 cache.nixos.org（实测该 FOD `/nix/store/cxyk83xx…-rainbow-delimiters.nvim` 在 cache.nixos.org 与 NJU/TUNA/USTC/SJTU 四个镜像全 404，而同一 store 随机取 3 个 `-source` FOD 均为 200；drv 的 `outputHash` 与社区缓存 narinfo 的 `NarHash: sha256:0zy93xwc…` 一致）。旁证：store 中已存在此前 substitute 来的 `2n5q…-vimplugin-rainbow-delimiters.nvim-0.12.0`，说明 flake 更新换掉 neovim/插件派生路径前并不需要现抓——本次是路径变化与上游不可达同时发生。另注：报错开头的 `options.json` 警告是求值期噪音（`nixosOptionsDoc` 把 nixpkgs 源码路径写进 JSON 字符串，string context 丢失），与本故障无关。

改动：`home/nix-cn.nix` 的 `substituters` 末位加 `https://nix-community.cachix.org`；`modules/fix-network.nix` 加 `nix.settings.trusted-public-keys = [ <cachix 公钥> ]`；`bootstrap/{linux,darwin,nixos}.sh` 的缓存变量追加该地址、新增 `CACHIX_PUBLIC_KEY`，以 `extra-trusted-public-keys` 写入（multi 写 daemon 的 `/etc/nix/nix.custom.conf`；linux 单用户写用户级 nix.conf 与 `NIX_CONFIG`；nixos.sh 另入 `NIX_CONFIG`）；三个脚本的幂等跳过标记由 NJU 改为 `nix-community.cachix.org`，使旧配置被重写一次而不是跳过；`AGENTS.md`/`README.md` 同步说明与手工补救命令。公钥刻意不进 `home/nix-cn.nix`：那会落到 standalone 用户 nix.conf，而 `trusted-public-keys` 对非受信用户（本机实测 `trusted-users = root`）是受限设置，每次连 daemon 都会打印 `ignoring the client-specified setting`。

验证（本机 Fedora 44 / WSL2 / Determinate Nix 3.22.2，standalone 目标 `.#x86_64-linux`）：① 公钥经 `nix store verify --store https://nix-community.cachix.org` 实测——`mB9F…` 判定通过、旧引用的 `LwCD…` 报 `path … is untrusted`，故取 `mB9F…`；② `nix config show` 实测 `extra-trusted-public-keys` 为追加语义（内置 cache.nixos.org-1 与安装器的 flakehub 各键均保留）；③ 用锁定的 nixpkgs 26.11 源码 `lib.nixosSystem` 对改后的 `modules/fix-network.nix` 做定向求值，得 `substituters = 四镜像 + cache.nixos.org + cachix`、`trusted-public-keys = cache.nixos.org-1 + cachix`（即 `nix.settings` 的 listOf 合并不会顶掉官方 key）；④ 三个脚本 `bash -n` 通过；把脚本中真实的 2/7（nixos.sh 为 1/7）代码块抽出桩测：multi 旧配置升级只写一次、重跑跳过、无重复行，linux 单用户分支在已有 `substituters` 时只补公钥、二次运行不重复，HM symlink 分支不落盘，nixos.sh 的 `NIX_CONFIG` 在带/不带 token 两种情况下按行正确拼接；⑤ `git diff --check` 干净。

未验证：`hms` 真实 substitute（需 root 先按 README 把 cachix 写进本机 `/etc/nix/nix.custom.conf`，属用户侧动作，本机 `/etc/nix` 未改动）；NixOS 桌面/WSL 与 darwin 目标的构建与激活；flake 五输出的完整求值/构建——本机 flake 输入（home-manager / nixvim tarball）不在 store 且 api.github.com 被污染，`nix eval`/`nix build` 均卡在取输入阶段，故上述③是对受影响模块的定向求值而非整 flake 求值；CI 在本批提交上的运行。

## 2026-09-24 bootstrap 派发 → nixos.sh adopt 实机首跑 + 幻影 cgroup 二现（NixOS-WSL 26.11，本机 wsl）

无代码改动；`bootstrap/bootstrap.sh`（派发器 → sudo 重 exec → `nixos.sh` adopt）在 NixOS-WSL 实机首跑——此前 install/adopt 两链路均未上过实机，派发器的 NixOS 分支亦为首次实跑。以 xuqihao 启动：派发器正确识别 `/etc/NIXOS` → nixos.sh；模式 adopt、目标 `.#wsl`（WSL 内核标记）、仓库 `/etc/nixos`；日志按设计落 root 侧 `/root/.local/state/nix-roam/nixos-20260924-155717.log`。

验证（实机，1–5/7）：1/7 镜像信任已配置跳过 ✓，且正确识别 `/etc/nix/nix.conf` 为 nix.settings 托管 symlink → 不追加 include、镜像经 `NIX_CONFIG` 生效 ✓；2/7 token 留空沿用旧值 ✓（stdin 交互、未入日志）；3/7 `/etc/nixos` 已是本仓库克隆 → 复用不重拉 ✓；4/7 `/etc/NIXOS` 读不出原系统版本（该文件无版本串）→ 按共享 26.05 继续 ✓（本机 flake 即 26.05，无偏差）；5/7 `nixos-rebuild switch → .#wsl` 构建并激活 gen 4（fm49i01…，与 gen 2 同闭包；gen 3 为 9-19 临时树）✓，`home-manager-xuqihao.service` 15:57:28 激活成功（系统级服务不走用户总线）。

发现一（宿主故障二现，非仓库回归）：stc exit 4——`reloading user units for xuqihao: Failed to open dbus connection (Unable to autolaunch a dbus-daemon without $DISPLAY)`。与 2026-09-19 首现同因：本 boot `user@1000.service` 全程未起、`/run/user/1000/bus` 缺失 → 仅用户单元重载一步失败，系统激活本身成功。恢复：Windows 侧 `wsl --shutdown` 重开 → `user@1000.service` 263ms Ready、用户级 NixOS activation 完成、`systemctl --user is-system-running` = running；fresh boot 直接加载 gen 4 用户单元，本轮未重跑 switch。两现间隔 5 天（kernel 6.6.114.1-microsoft-standard-WSL2 / systemd 261.2），再复现应追 WSL2 内核/systemd upstream。

发现二（脚本边界，待改进项）：`set -euo pipefail` 下 stc exit 4（成功带警告）直接中止脚本，6/7（adopt 场景本为跳过提示）与 7/7（收尾提醒）未执行；激活已成功故无功能损失，但收尾信息被吞——后续可考虑 5/7 对 exit 4 容忍（仅非 4 的非零才中止）。

未验证：install 链路（live ISO）仍无实机；adopt 的外来 `/etc/NIXOS`/`/etc/nixos` 备份分支与 stateVersion 不符确认分支（本机仓库即原生、版本一致未触发）；恢复后重跑 switch 的 exit 0（本轮以 fresh boot 替代，9-19 已单独验过）；CI 在本批提交上的运行。

## 2026-09-24 WSL 默认用户改为询问后写入 /etc/wsl.conf（Fedora 44 / WSL2 + ArchLinux-WSL 实机）

改动：`linux.sh` 守卫建号分支的 WSL 提示升级为询问（`[Y/n]` 默认 Y）：同意则把 `[user] default=<username>` 合并进 `/etc/wsl.conf`——保留既有段落与键、原文件带时间戳备份、写失败仅警告不中断安装；拒绝则保留原手动提示。合并逻辑为纯 bash 函数 `wsl_conf_merge()`（内建 + 正则，零外部依赖）：实测作者日常 Fedora WSL 未安装 gawk，`awk` 不能假设存在（`darwin.sh` 的 awk 保留——macOS 系统自带 BSD awk）。

验证：`wsl_conf_merge` 自脚本抽出单测 8/8 通过（文件不存在/空/仅 `[boot]`/已有 default 替换/裸 `[user]`/`[user]`+其他键/多段保留替换/幂等重入）；本机桩测 root+无 sudo 全链路（建号 y → wsl.conf 询问 n 跳过 → su 切换重跑 → 第二轮中止）通过，且本机真实 `/etc/wsl.conf` 未被触碰；**ArchLinux-WSL 实机**：建号 → 询问回车取默认 Y → 写入成功，合并后 `[boot] systemd=true` 原样保留、新增 `[user] default=xuqihao`，备份 `/etc/wsl.conf.bak-20260924-151406`（20 字节原文），随后 su 切换与 1/7 Nix 安装照常（30s 截停于下载中）。途中顺带实测「目标用户已存在」分支输出（含 su -l 提示）。两个环境层发现：① binfmt 的 WSLInterop 注册一度丢失致 `wsl.exe` 无法执行（有界截停互操作进程的副作用），`echo :WSLInterop:M::MZ::/init:PF > /proc/sys/fs/binfmt_misc/register` 恢复；② 此前「有界截停」实际未截住 su 之后的进程树（地下继续跑到 home-manager 步骤），清理时须按用户 `pkill`——本轮起已按此清理。

未验证：七步全程实机跑完；非 root+sudo 路径的 wsl.conf 写入（桩覆盖，写入前缀不同逻辑同构）；`wsl --shutdown` 重开后默认用户实际生效（需 Windows 侧操作）；CI 在本批提交上的运行。

## 2026-09-24 守卫建号支持 root 直跑与无 sudo 环境（Fedora 44 / WSL2 standalone Nix + ArchLinux-WSL 实机）

改动：`bootstrap/linux.sh` 0.7 守卫的提权判定从「非 root 且可 sudo」扩为「root 本身或非 root 可 sudo」；root 分支不加 sudo 前缀执行 `useradd/usermod/passwd`、仓库复制走 `cp -a + chown -R`、切换重跑以 `su --login <user> -c '<单串>'` 为主（`runuser --login -c` 兜底）、root 且无 sudo 二进制时预建 `/nix`（0755，属新用户）使重跑落入单用户安装；已存在目标用户的分支补 `su -l` 提示。起因：在 root-only、未装 sudo 的 ArchLinux-WSL 上，原判定在 `have sudo` 处失败，交互询问从未出现。

验证：**ArchLinux-WSL（root-only / 无 sudo / systemd 开启）实机全链路**——交互询问 → `useradd` 真实建号 → 无 sudo 说明 → `/nix` 预建 → 仓库复制属 xuqihao → WSL 提示 → `su -l` 切换成功 → 第二轮日志落在 `/home/xuqihao/.local/state/` → 模式判定 `single-user（systemd: yes，sudo: no）` → 官方安装器真实下载并安装 Nix 2.35.2 至预建 `/nix`，30s 超时截停（完整七步未跑完，属有界验证；passwd 用桩避免真实设密）。本机（Fedora 44）桩测回归：非 root 拒绝/同意两分支 + root+无 sudo（minbin 模拟）全链路均通过。过程中两个实测发现：① `runuser/su -- CMD ARGS` 多参数形式在 util-linux 上报 `cannot execute binary file`（Fedora/Arch 双现）→ 统一 `-c` 单串 + `printf %q`；② `runuser -c` 在该 Arch 的 logind 异常下挂死（其 PAM `session include system-login` 含 pam_systemd；`su` 为纯 pam_unix 不受影响）→ su 为主、runuser 兜底。Arch 侧终态：用户 xuqihao、`/home/xuqihao/nix-roam` 副本与空 `/nix`（属 xuqihao）保留供完整安装，半装的 store/profile 残留已清。

未验证：七步全程在实机一次跑完（截停于 1/7）；真实 `passwd` 交互（实机用桩）；root+有 sudo 的实机分支（仅桩覆盖）；`darwin.sh` root 路径与整条链路（macOS 必有 sudo，理论经 `sudo -v` 即通过，未实机）；CI 在本批提交上的运行。

## 2026-09-24 standalone 用户守卫改为可建号（Fedora 44 / WSL2 standalone Nix，本机）

改动：`bootstrap/linux.sh`/`darwin.sh` 的 0.7 目标用户守卫从「用户名不符即中止」升级：目标用户已存在 → 提示换登重跑（不动既有账号）；交互终端且可 sudo → 询问是否创建 meta.json 定义的系统用户并以它继续——linux 走 `useradd -m` + 交互 `passwd` + best-effort 加入 sudo/wheel 提权组，darwin 走 `sysadminctl -addUser … -admin -password prompt`；随后仓库 `cp -a` 到新用户家目录（失败回退当前副本只读使用），`exec sudo --login --user` 以新用户重跑本脚本（与 NixOS 侧 flake 直接 `users.users.<username>` 建号对齐）；拒绝/非交互/无 sudo 仍 fail-loud 中止并给 meta.json 指引。WSL 下打印 `/etc/wsl.conf` 默认用户设置提示但不自动写。

验证（桩测，本机）：`linux.sh` 分支实跑覆盖——非交互中止 ✓；交互拒绝（改 meta.json 指引）✓；交互同意全链路（useradd/usermod/passwd/getent 经 PATH shim 桩替，真实执行了提权组校验、`cp -a` 复制、WSL 提示、以新用户重跑**复制出的仓库副本**、第二轮守卫再触发）✓；复制失败回退原仓库重跑的兜底分支 ✓；目标用户已存在（root）提示换登 ✓。四脚本 `bash -n` 通过。桩测期间发现并修正的三处均为桩缺陷（sudo shim 漏过滤 `-v`、getent 桩的 passwd 行少 GECOS 字段、useradd 桩未建家目录），非脚本缺陷。

未验证：真实 `useradd`/`passwd`/提权组在实机的执行、以新建用户身份走完七步安装（本机登录名即 xuqihao，无法自然触发真实建号分支）；`darwin.sh` 整条链路含 `sysadminctl -addUser -password prompt` 语法（按官方文档核对，从未实机运行）；CI 在本批提交上的运行。

## 2026-09-24 standalone 输出改按系统名命名（Fedora 44 / WSL2 standalone Nix，本机）

改动：`homeConfigurations` 三个 standalone 输出由 `xuqihao` / `xuqihao-aarch64` / `xuqihao-darwin` 改名为 `x86_64-linux` / `aarch64-linux` / `aarch64-darwin`（输出名不再随用户名变化；`homeDirectory` 与模块内容不变）。联动：`home/common.nix` 的 `hmTarget`（`hms` 目标）改为系统名；`bootstrap/{bootstrap,linux,darwin}.sh` 默认 target 按架构取系统名，显式传参须与本机架构一致（新增 fail-loud 校验），目标用户守卫从「target 剥后缀还原用户名比对 `id -un`」改为「直接比对 meta.json 的 username」——顺带堵上此前「显式传自己的登录名即可绕过守卫、直到激活阶段才失败」的缺口；`bootstrap.sh` 不再为派发读 meta.json；CI `eval.yml` 输出名同步。

验证（本机求值/构建/激活）：五输出求值通过；两 NixOS toplevel drvPath 与改动前逐字节一致（`hms` 不注入 NixOS 侧），三个 standalone 输出 drvPath 如预期变化——构建 x86_64 activation 仅 4 个派生重建（bashrc→home-manager-files→generation 链），证明内容面只有 bashrc。本机激活 `.#x86_64-linux` 成功（gen 14，2026-09-24 00:42），新 bashrc 的 `hms` 指向 `.#x86_64-linux`；激活时 systemd 报 wslg-session.service degraded 为本机宿主既有问题，与本改动无关。另注：本机此前 profile 停在 2026-09-17 的 gen 13（仍含旧 hms 别名文本与 standalone 上早已门控排除的 `nrs='sudo nixos-rebuild'` 别名），本次激活一并追平。三脚本 `bash -n` 通过。

未验证：aarch64 / darwin 输出仅求值（无 ARM/macOS 实机）；darwin.sh 新目标校验与守卫文案未实跑（与 linux.sh 同构改法，经 bash -n + 逐段核对）；bootstrap 全链路未在已激活的本机重跑；CI 在本批提交上的运行。

## 2026-09-19 nrs/nh 实机首验 + WSL cgroup 用户管理器故障（NixOS-WSL 26.11，本机 wsl）

无代码改动；对 9d4d8e7（多机兼容性五连改）遗留未验项 `nrs` 的实机验证。本机当时代际：gen 7（2026-09-19 13:35，已含 nh 与新别名，由用户经 sudo nixos-rebuild 激活）。

验证：`bash -ic 'type nrs && nrs'` 实跑——别名解析 ✓、cwd 相对 `.` 解析 ✓、`--hostname` 默认匹配 `.#wsl` ✓、构建 1s 全缓存 ✓、**nvd 代际 diff 输出正确**（2101→2101 路径、15.9 GiB→15.9 GiB、DIFF 0 字节——同树切换的预期值）、nh 对失败的呈现清晰（结构化错误 vs nixos-rebuild 的裸串）。

发现（宿主故障，非仓库回归）：激活步 stc exit 4——`reloading user units for xuqihao: Failed to open dbus connection (Unable to autolaunch a dbus-daemon without $DISPLAY)`。A/B 对照：`sudo nixos-rebuild switch --flake .#wsl` **同样 exit 4、同样警告**，证明与 nh 无关。根因：本次 boot（13:34）起 `user@1000.service` 无法启动（`Failed to spawn executor: Device or resource busy`，同秒即败）；logind 建了 session c1 但从未尝试启动用户管理器；`/run/user/1000/bus` 不存在 → stc 用户单元重载失败。cgroup 现场确认幻影占用：`user.slice/user-1000.slice/user@1000.service` 下 `init.scope`/`session.slice` 的 `cgroup.procs` 为空、`cgroup.threads` 报 `0`、`cgroup.events` `populated=1` 永不落零、三者 `rmdir` 均 EBUSY（与 spawn 失败同 errno）；对照实验：`systemd-run --uid=1000 --slice=user-1000.slice` 可正常 spawn，问题特定于该单元的 cgroup 子树。上一 boot（9月16日，systemd[451]）用户管理器正常。影响面：本 boot `systemctl --user` 与 HM 用户单元全部不可用；系统其余正常（`is-system-running` running、gen 7 不变、无新代际——闭包相同未建 gen 8）。

未验证：~~exit 0 的完整 nh 切换~~——已补验（同日 13:57）：Windows 侧 `wsl --shutdown` 重开后 `user@1000.service` 正常启动（幻影 cgroup 未随 fresh boot 复现，单次观察），`nrs` 重跑 **exit 0**，激活 + bootloader 步骤全过、无警告，系统保持 `running`、gen 7 不变（闭包相同未建新代际）；过程中注意到 dirty Git tree 会令 nh 打印 `warning: Git tree ... is dirty`（本地未提交的文档改动所致，无害）。幻影 cgroup 是否为偶发仍待观察（复现则需追 WSL2 内核/systemd 261 upstream）。桌面输出未动。

## 2026-09-19 多机兼容性五连改（Fedora 44 / WSL2 standalone Nix，本机）

改动：借鉴 ZaneyOS 评审结论的五项：① per-host `hosts/<host>/variables.nix` 旋钮（`timeZone` 自 `profiles/nixos-base.nix` 迁出，flake 两个 nixosConfigurations 块以 `vars` specialArg 注入，接线点唯一）；② `profiles/hardware/` 休眠 GPU/VM profile 层（nvidia/amd/intel/vm-guest；nvidia 的 prime offload 由 `vars.gpuBusIDs` 条件启用，未提供时为纯 dGPU 配置）；③ `hosts/_template/` 主机模板 + `bootstrap/nixos.sh` 任意 `--target <主机名>` 脚手架（复制模板并替换 `__HOSTNAME__`，打印桌面/CLI 两种 flake 输出样例，人工粘贴后 grep 校验输出存在，不自动改 flake.nix；install 链路 `hosts/nixos/hardware-configuration.nix` 与 `.#nixos` 等硬编码泛化为 `${TARGET}`）；④ linux/darwin/nixos 三条链路全程时间戳日志（`${XDG_STATE_HOME:-$HOME/.local/state}/nix-roam/`）；⑤ `programs.nh.enable`（不设 flake、不开 clean）+ `nrs` 改走 `nh os switch --diff always .`（门控自 isLinux 收紧为 `isLinux && !isStandalone`，standalone 上原 sudo 形式同样必然失败）。

验证（本机求值/构建，未激活）：五输出 drvPath 求值全部通过；两主机 `time.timeZone` 经 vars 求值 `Asia/Shanghai`，`programs.nh.enable` 两边 `true`、`clean.enable` `false`、`flake` 未设。硬件层不在任何输出 import 链上（CI 不覆盖），四个 profile 经 `extendModules` 叠加 wsl 配置求值：nvidia 无 gpuBusIDs 时 prime 块缺省、注入 nvidia+intel 时 offload 与 `intelBusId` 正确接线，amd/intel early KMS 与 intel VA-API 包、vm-guest 两服务均按预期。模板经真实脚手架路径（仓库内 cp + sed）+ 桌面模块集（desktop.nix + hermes 模块 + 集成 HM）从零 `nixosSystem` 求值通过（hostname/systemd-boot/ext4 根/timeZone/hermes/HM 用户全对）；过程中确认 `networking.hostName` 的类型模式会拒绝未替换的 `__HOSTNAME__` 占位符（下划线不可开头）——sed 失败时求值大声失败。四脚本 `bash -n` 通过；linux.sh 日志以错误 target 触发用户守卫实跑验证（日志文件落盘且内容完整）。standalone x86_64 activationPackage 构建通过，仅 bashrc 相关 4 个派生重建（与 nrs 门控改动的预期影响面一致），产物 `home-files/.bashrc` 已无 `nrs`、`hms` 函数仍在。

未验证：`nh os switch` 实机切换（需 NixOS 桌面/WSL，桌面下次 `nrs` 即首验，注意确认代际 diff 输出）；GPU/VM profile 无实机；nixos.sh 脚手架流程未实跑（仅求值级验证，脚本路径改动经 bash -n + 逐段核对）；install 链路、macOS 输出、darwin/nixos 日志实跑（仅 linux.sh 前段实测）；CI 在本批提交上的运行（推送后自动触发）。

## 2026-09-18 WSL getty@tty1 mask（NixOS-WSL 26.11，本机）

改动：`hosts/wsl/default.nix` 增加 `systemd.units."getty@tty1.service".enable = false;`。背景：本机当日从 26.05 桌面代（systemd 257）切到 26.11 wsl 代（systemd 261）时，切换事务经 getty.target 拉起 `getty@tty1`，WSL 无真实 tty1，agetty 收 HUP 即退 → restart 循环 → start-limit，`switch-to-configuration` 以 status 4 失败、系统 degraded。诊断依据：开机段日志无任何 getty/Login Prompts 条目、静态配置与 generator 均无 tty1 的 wants 链接（generator 仅加已被 mask 的 console-getty）→ 正常开机不会拉起它，失败仅发生在跨版本切换事务内。

验证：该选项求值为 `false`；wsl toplevel 构建通过（`5pcvyqz4…`），产物 `etc/systemd/system/getty@tty1.service` 指向 `unit-getty-tty1.service-disabled`（即 `/dev/null` mask，与系统对 console-getty 的处理同机制）；桌面输出 `systemd.units` 无该单元声明，行为不变。未验证：实际 switch 激活与重启后 degraded 清除（待本机执行 `nixos-rebuild switch --flake .#wsl` + Windows 侧 `wsl --shutdown`，后者同时令 wsl.conf 的 hostname=wsl 生效）。

## 2026-09-17 架构收敛 + CI 构建层 + 文档重构（Fedora 44 / WSL2 standalone Nix）

改动：本地用户名单点移至仓库根 `meta.json`（`flake.nix` 经 `builtins.fromJSON` 读取；`bootstrap.sh`/`linux.sh`/`nixos.sh` 改为 sed 解析同一文件并在解析失败时中止——删掉了三处 `xuqihao` 静默兜底与 `darwin.sh` 的硬编码默认 target）；`pkgsFor` 统一实例化 unstable + stable（共享 `nixpkgsConfig`），`mkStandaloneHome` 不再内联 `import nixpkgs`；`stateVersion` 收敛到 flake 顶层单点并经 `specialArgs`/`extraSpecialArgs` 贯通 `home.stateVersion` 与 `system.stateVersion`；删除无消费者的 `supportedSystems`/`forAllSystems`；`hms` 从别名字符串改为 bash 函数（`programs.bash.initExtra`）；`eval.yml` 增加 standalone x86_64 activation package 构建步（含 runner 磁盘清理，timeout 30→45）；验证后移除共享 `nixpkgsConfig` 中无引用的 `electron-38.8.4`；验证记录拆至本文件。

验证（本机求值/构建，未激活）：五输出求值全部通过，`nixos`/`wsl` toplevel drvPath 与改动前基线**逐字节一致**（干净树对比；含移除 electron 条目后复测），standalone x86_64/aarch64/darwin 按预期变化——经 activationScripts / environment.etc / systemd.units / home.file / bash 选项的 JSON 语义 diff 确认差异仅为 standalone 侧 bashrc 中 `hms` 的别名→函数文本，NixOS 侧无任何语义差异。过程中发现并记录一个 HM 陷阱：`initExtra` 用字符串级 `lib.optionalString` 置空会生成多一个空行的 bashrc（与未设置不同），必须属性集级 `lib.optionalAttrs` 门控。五个 bootstrap 脚本 `bash -n` 通过；sed 提取 stub 测 6 例（正常/缺 key/缺文件/紧凑 JSON/仓库实文件/中止分支）全过；新 CI 构建步本地预演成功（除 HM 自身 5 个派生外全部 substituter 命中，成本可控）；`electron-38.8.4` 移除经五输出求值 + standalone 构建双向验证。

未验证：任何主机的实际激活、aarch64 实机构建、macOS、bootstrap 安装链路实跑、GitHub Actions 上新 workflow 步的运行（workflow 变更需手动双推后才生效）。

## 2026-09-17 follow-up pass on Fedora 44 / WSL2 standalone Nix (offline evaluation)

`bootstrap/bootstrap.sh` had been committed with mode 644 — fixed to 755 to match its siblings; the zsh session-vars append in `home/standalone-linux.nix` is now gated exactly like fish (login shell is zsh or `~/.zshrc` already exists), so bash-only hosts no longer get a stray `~/.zshrc` created on the next activation — this supersedes the unconditional zsh append described in the boundary-expansion entry below (whose live activation test ran in the separate Ubuntu 26.04 distro, not on the daily-driver Fedora 44 host where the committed blocks are still unactivated); README/AGENTS environment wording regularized (validation records name their distro explicitly; the README status table no longer pins the volatile distro name). All five outputs re-evaluate on the current lock after the gating edit; all bootstrap scripts pass `bash -n`. Unverified: live activation of the gated blocks on any host.

## 2026-09-17 boundary expansion on Ubuntu 26.04 / WSL2 standalone Nix (live host)

Added `homeConfigurations.xuqihao-aarch64` (aarch64-linux; shared Linux-only packages verified available at the locked revs — root 6.40.00 not broken, in platforms); `hms` and the new unified entry `bootstrap/bootstrap.sh` now select the standalone target by architecture; standalone Linux gained idempotent guarded zsh/fish session-vars appends in `home.activation` (live-activated here — the `~/.zshrc` guard block was created; fish only acts when fish is actually in use); `bootstrap/linux.sh` gained a WSL1 rejection, a single-user install branch (official installer `--no-daemon` for no-systemd/no-sudo hosts, mirrors in user-level nix.conf plus exported `NIX_CONFIG`, `/nix` one-time-root pre-flight with the exact admin command) and HM-symlink skip guards on the token/flakes steps (previously darwin-only). All five outputs evaluate on the current lock; desktop and WSL toplevel drvPaths are byte-identical to the previous commit, the darwin activation derivation is unchanged, and the x86_64 standalone drvPath changed as expected (hms alias text + new activation blocks). The unified entry ran end-to-end on the live host — a non-tty session auto-selected the single-user branch and exercised its idempotent guards, producing generation 2 — and dispatcher branches were stub-tested (Darwin, WSL1, aarch64/riscv64, zsh note, FreeBSD, explicit-arg override, suffix stripping). Unverified: an aarch64 hardware build, a genuinely rootless single-user install on a machine without sudo, and macOS.

## 2026-09-17 username single-point refactor on Fedora 44 / WSL2 standalone Nix (offline evaluation)

The local username is now defined once as `username = "xuqihao"` at the top of `flake.nix`'s `let` and flows to all NixOS modules and HM entries via `specialArgs`/`extraSpecialArgs` (`users.users.*`, `home-manager.users.*`, standalone output names, `mnt.nix` mount owner); `hms` gained a current-user guard that refuses cleanly on mismatch; `bootstrap/linux.sh`/`darwin.sh` abort up front when the target's username differs from the current login user; `bootstrap/nixos.sh` reads the password-setup username from `flake.nix`. All four outputs evaluate on the current lock; desktop and WSL toplevel drvPaths are byte-identical to the previous commit (semantics-preserving under the default username), standalone drvPaths changed as expected (new `hms` alias text). The `hms` accept/refuse branches, the bootstrap refusal and the flake-username extraction were runtime-tested locally with stubs. Nothing was built or activated; desktop boot, Darwin build and WSL activation remain unverified.

## 2026-09-16 repair/cleanup pass on Fedora 44 / WSL2 standalone Nix (offline evaluation)

After removing the stale `programs.dms-shell.enableSystemMonitoring` definition (removed upstream in the locked nixpkgs; it had broken desktop evaluation since the 2026-09-14 lock bump), all four outputs evaluate — desktop toplevel (hermes-agent input stubbed locally due to GitHub 429), WSL toplevel, standalone Linux and standalone Darwin activation packages. WSL and standalone Linux drvPaths were byte-identical across the P0/P1 edits, confirming those were semantics-preserving. Changes this pass: rustdesk-server disabled (placeholder relay host), podman commented out (docker stays), niri/hypr dotfiles now deployed via `home/default.nix`, orphan dotfiles deleted, `hms` gated behind `isStandalone`, the unused nixpkgs-master channel removed (flake.nix + flake.lock + all plumbing), plasma6/gnome kept with cosmic commented out. None of this was built or activated; desktop boot, Darwin build and WSL activation remain unverified.

## 2026-09-14 runtime split validation on NixOS 26.11 / WSL2

WSL system closure and standalone Linux activation package built without activation; standalone Darwin activation derivation and desktop system derivation evaluated. Desktop/WSL Node, pnpm, Python, R and ROOT package paths match exactly. The built WSL profile passed Node/npm/pnpm/uv execution, npm registry queries, all 15 configured Python module imports, and ROOT/R computations through PyROOT/rpy2. After restoring shared C++ ROOT, WSL and standalone Linux were rebuilt and the standalone artifact passed a C++ ROOT computation. This does not verify activation of these edits, a Darwin build, or desktop boot. Desktop full build remains unverified after a QQ source download failure; further QQ diagnosis was skipped and QQ is unchanged at the user's request.

## 2026-09-05 historical verification on AlmaLinux 9.8 / WSL2 standalone Nix

WSL's system closure built; the desktop host-layout refactor preserved its derivation; standalone Linux/Darwin activation derivations evaluated. These records predate later edits and do not certify the current lock/package set. Activation and subsequent boot/login of the current WSL edits, and a Darwin build, remain unverified; the 2026-09-14 checks exercised build artifacts without activating these edits. GitHub synchronization was separately verified by pushing a documentation commit only to Gitee and observing Actions update GitHub.
