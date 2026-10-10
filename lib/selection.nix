# lib/selection.nix — 跨前端模块选择解析器（模块注册表 + 机器本地选配）
#
# 单一事实源 modules/registry.json：模块名 → 各前端实现文件 + darwin 白名单旗标。
# 机器本地选配 local.<key>.json（仓库根、gitignored、由 roam module 维护）：
#   - git 求值视图（CI / pre-push / 远端 git+https / 裸 `.#`）看不到 gitignored 文件
#     → 走调用方显式给出的入库 default（默认集在各主机入口可见，延续 explicit-imports）；
#   - `path:./.` 求值视图（roam 全链路、CI 模块矩阵）整目录拷贝、local 文件可见
#     → 其 modules 列表为权威完整选择（整体替换 default，不做增量合并）。
# 未知名 / 该前端无实现 / darwin 白名单外 / local 文件 host 字段与 key 不符 → throw
# （fail-loud：选错机器的文件宁可中止，也不静默回落装错组合——与 meta.json 同规约）。
#
# 前端（front）：
#   "nixos"        系统级模块（modules/<名>/nixos.nix，nixos 与 NixOS-WSL 主机共用）
#   "home-linux"   standalone Linux 用户级包列表（modules/<名>/home.nix）
#   "home-darwin"  同上但强制 darwin 白名单（保守边界：registry darwin=true 才放行）
#
# 导出：
#   selection { front, key, default ? [] }  → { modules = [名…]; files = [path…] }
#   selectionModule { front, key, default } → NixOS/HM 通用模块：
#     声明只读元信息 config.roam.selectedModules（roam module init / status 经
#     `nix eval path:./.#…config.roam.selectedModules` 一次轻求值读取当前有效选择）
#     并把选中文件挂进 imports。
rec {
  selection =
    { front, key, default ? [ ] }:
    let
      registry = builtins.fromJSON (builtins.readFile ../modules/registry.json);
      byName = builtins.listToAttrs (
        map (m: {
          name = m.name;
          value = m;
        }) registry.modules
      );

      # pathExists 对源视图中不存在的路径返回 false（尖刺 2026-10-11 实证：git 视图
      # 看不到 gitignored 文件，path: 视图可见；插值路径行为相同）
      localPath = ../local.${key}.json;
      local = if builtins.pathExists localPath then builtins.fromJSON (builtins.readFile localPath) else null;

      names =
        if local == null then
          default
        else if (local.host or key) != key then
          throw "local.${key}.json 的 host 字段是 \"${local.host or "<缺失>"}\"，与输出 ${key} 不符（输出改名后须删除该文件并 roam module init 重建）"
        else
          local.modules;

      fileFor =
        m:
        if front == "nixos" then
          m.nixos or false
        else if front == "home-linux" || front == "home-darwin" then
          m.home or false
        else
          throw "lib/selection.nix: 未知前端 ${front}（可用：nixos / home-linux / home-darwin）";

      # 文件位置按约定派生：modules/<名>/nixos.nix 与 modules/<名>/home.nix。
      # 必须用路径字面量插值（../. + 字符串拼接的绝对路径在纯求值下禁止 import；
      # 插值锚定源树、Nix 自动复制进源副本——2026-10-11 /tmp 尖刺实证）。
      pick =
        name:
        let
          m = byName.${name} or (throw "模块 ${name} 不在注册表 modules/registry.json（roam module list 查看；名字以 registry 为准）");
          has = fileFor m;
        in
        if !has then
          throw "模块 ${name} 没有 ${front} 实现（注册表标注该前端不适用；roam module list 的 fronts 列）"
        else if front == "home-darwin" && !(m.darwin or false) then
          throw "模块 ${name} 不在 darwin 白名单（保守边界：home-darwin 仅接受注册表 darwin=true 的模块）"
        else if front == "nixos" then
          ../modules/${name}/nixos.nix
        else
          ../modules/${name}/home.nix;
    in
    {
      modules = names;
      files = map pick names;
    };

  # 只声明元信息 option 的轻模块：standalone 入口用（其 files 以包列表函数 import 进
  # home.packages，不能走 selectionModule 的 imports 挂载，但同样需要暴露有效选择）。
  metaModule =
    { lib, ... }:
    {
      options.roam.selectedModules = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "本输出经 lib/selection.nix 解析后的可选模块集（机器本地 local.<key>.json 优先于入库默认集）";
      };
    };

  selectionModule =
    args@{ front, key, default ? [ ] }:
    let sel = selection args; in
    { ... }: {
      imports = [ metaModule ] ++ sel.files;
      config.roam.selectedModules = sel.modules;
    };
}
