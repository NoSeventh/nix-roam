# Nix 侧中国大陆网络适配共享化设计：`fix-network.nix` → `home/nix-cn.nix`

- 日期：2026-08-05
- 状态：已批准（待实现）
- 作者：xuqihao

## 1. 目标

把 `modules/fix-network.nix` 中面向中国大陆网络的 **Nix 侧**适配（`nix.settings`）从"仅 NixOS 生效"扩展到 flake 的所有安装路径（NixOS / standalone Linux / WSL / macOS），并消除重复：

- **单一事实源**：新增 `home/nix-cn.nix` 共享模块，NixOS 与 standalone 两条链路共同 `imports`。
- **NixOS 行为零变化**：daemon 级配置（`/etc/nix/nix.conf`）保持现状。
- **standalone 补上适配**：WSL / 非 NixOS Linux / macOS 获得用户级 Nix 配置中安全生效的部分。

## 2. 非目标

- **不做** flake 输入镜像化（gitee / `nix.registry` 等）——本次只共享二进制缓存镜像配置。
- **不改** `fix-network.nix` 中的系统级设置：`auto-optimise-store`、`download-buffer-size`、`NIXPKGS_ALLOW_UNFREE` 继续留在 NixOS 侧。
- **不改** `bootstrap/linux.sh`（不写 `/etc/nix/nix.conf`、不加 `trusted-substituters`）。多用户 daemon 机器上的完整生效是可选后续，不在本次范围。
- **不**把共享模块放进 `home/common.nix`——否则 NixOS 用户侧也会生成 `~/.config/nix/nix.conf`，在非 trusted 用户下产生 "untrusted substituter / restricted setting" 警告。

## 3. 现状与实测结论

现状：

- `flake.nix` 的 `generatedModules` 自动载入 `modules/*.nix`，`fix-network.nix` 的 `nix.settings` 只作用于 NixOS daemon。
- standalone 入口（`home/standalone-linux.nix` / `home/standalone-darwin.nix`）只 import `home/` 下的文件，因此 WSL / 非 NixOS / macOS 完全缺失镜像配置。

实测（本机，Nix 2.34.8 + 多用户 daemon，`trusted-users = root`）：

- HM 的 `nix.settings` 选项存在（`nix eval .#homeConfigurations.xuqihao.options.nix.settings.description`），值会写入 `~/.config/nix/nix.conf`。
- NixOS 侧 `nixosConfigurations.nixos.config.nix.settings.substituters` 当前即为 TUNA / USTC / cache.nixos.org，行为确认。
- 用户级配置在非 trusted 用户下的实际效果（`NIX_USER_CONF_FILES` + `nix store info` 实测）：
  - `download-buffer-size`、`auto-optimise-store` → **忽略** + "restricted setting" 警告；
  - TUNA / USTC 等非默认 `substituters` → **忽略** + "untrusted substituter" 警告；
  - `connect-timeout`、`fallback` → 正常生效。

结论：共享模块只能包含三端都安全生效的设置；daemon 级设置必须留在 NixOS 侧。

## 4. 设计

### 4.1 新增 `home/nix-cn.nix`

约 14 行的 NixOS / HM 双兼容模块（只声明 `nix.package` 与 `nix.settings`）：

```nix
# 中国大陆网络适配（Nix 侧共享配置，单一事实源）
# 被 modules/fix-network.nix（NixOS daemon）与 home/standalone-{linux,darwin}.nix（用户级）共同 import。
# 只放三端都安全生效的设置；daemon 级设置（download-buffer-size / auto-optimise-store）留在 fix-network.nix。
{ lib, pkgs, ... }:

{
  # HM 断言：生成 nix.conf 时必须指定 nix.package
  nix.package = pkgs.nix;

  nix.settings = {
    # 优先使用国内镜像站
    substituters = lib.mkForce [
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://cache.nixos.org/"
    ];

    connect-timeout = 5;
    fallback = true;
  };
}
```

### 4.2 改动 `modules/fix-network.nix`

- 增加 `imports = [ ../home/nix-cn.nix ];`。
- 删除重复的 `substituters`、`connect-timeout`、`fallback`（改由共享模块提供）。
- **保留**：`auto-optimise-store`、`download-buffer-size`、`NIXPKGS_ALLOW_UNFREE`、被注释的 GitHub token 块。

### 4.3 改动两个 standalone 入口

- `home/standalone-linux.nix`：`imports = [ ./common.nix ./nix-cn.nix ];`
- `home/standalone-darwin.nix`：`imports = [ ./common.nix ./nix-cn.nix ];`

### 4.4 生效矩阵

| 安装路径 | substituters | connect-timeout / fallback |
|---|---|---|
| NixOS（daemon 配置） | 全生效（现状不变） | 全生效 |
| standalone 单用户安装 | 全生效 | 全生效 |
| standalone 多用户 daemon（非 trusted） | 仅 trusted-substituters 内生效；TUNA/USTC 由 bootstrap 第 2 步授权后生效 | 全生效 |

## 5. 边界与错误处理

- `lib.mkForce` 只作用于 `substituters` 单个键（与 `fix-network.nix` 原语义一致），避免整块 `nix.settings` 强制覆盖掉 NixOS 侧 daemon 级设置（`auto-optimise-store`、`download-buffer-size`）；其余键按 Nix 模块系统正常合并。
- HM 的 `nix.settings` 带断言：生成 `nix.conf` 时必须同时指定 `nix.package`。共享模块一并提供 `nix.package = pkgs.nix;`；NixOS 侧 `nix.package` 默认即 `pkgs.nix`，无行为变化。
- 不引入新的权限变更、不触碰 `/etc/nix`。
- macOS 目标（`xuqihao-darwin`）仅做结构生效，不做实机构建验证（跨架构限制）。

## 6. 验证

```bash
# NixOS 侧值不变
nix eval --json .#nixosConfigurations.nixos.config.nix.settings.substituters
nix eval --json .#nixosConfigurations.nixos.config.nix.settings.auto-optimise-store

# standalone 两侧拿到共享配置
nix eval --json .#homeConfigurations.xuqihao.config.nix.settings
nix eval --json .#homeConfigurations.xuqihao-darwin.config.nix.settings
```

可选：`nix build .#nixosConfigurations.nixos.config.system.build.toplevel` 干构建确认 NixOS 无回归。

## 7. 变更文件清单

| 文件 | 操作 |
|---|---|
| `home/nix-cn.nix` | 新增（共享模块） |
| `modules/fix-network.nix` | 改（imports 共享模块，删重复项） |
| `home/standalone-linux.nix` | 改（imports） |
| `home/standalone-darwin.nix` | 改（imports） |

## 8. bootstrap/linux.sh 集成：国内镜像授权（已批准实现）

`bootstrap/linux.sh` 在“安装 Nix”之后插入新步骤 2/6“配置国内镜像信任”：

- 幂等地在 `/etc/nix/nix.custom.conf` 追加 `trusted-substituters = 清华/中科大`（Determinate 的系统 `/etc/nix/nix.conf` 自动 `!include nix.custom.conf`，用户修改应写进 `nix.custom.conf`）。
- 若该文件已含 TUNA 镜像 URL 则跳过，重复运行不叠加；`sudo mkdir -p /etc/nix` 兜底。
- 平台无关（Linux / macOS 的 Determinate 安装路径相同）。
- 镜像列表仍只维护在 `home/nix-cn.nix`；bootstrap 只做“授权”，不重复写 `substituters`。

## 9. 仍可选的后继

- daemon 级 `download-buffer-size`：多用户 daemon 机器上用户级设置会被忽略，如需可写进 `nix.custom.conf`（非必须）。
- 更彻底的墙内适配：flake 输入镜像化（gitee / `nix.registry`）。
