# 双模 Flake 实现计划（NixOS 系统配置 + 非 NixOS 便携 CLI 环境）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让本仓库 flake 在保持 NixOS 完整系统配置不变的前提下，新增 Home Manager standalone 模式，使任意 Linux/WSL（并预留 macOS）可通过 `home-manager switch --flake .#xuqihao` 拉起同一套便携 CLI 开发环境。

**Architecture:** 抽出一份共享 CLI 工具列表 `packages/cli-dev.nix`（单一事实源），分别喂给 NixOS 的 `environment.systemPackages`（系统级、sudo 可见）和非 NixOS 的 `home.packages`（用户级）。把现有 `home/default.nix` 中跨平台的部分抽到 `home/common.nix`，由 `home/default.nix`（NixOS）与新增的 `home/standalone.nix`（非 NixOS）共同导入。GUI HM 配置仅留 NixOS 入口。

**Tech Stack:** Nix flakes、NixOS、Home Manager（NixOS 模块 + standalone 两种用法）、nixpkgs unstable + nix-26.05 stable。

## Global Constraints

- Nix 代码 2 空格缩进；模块参数签名带省略号 `{ config, pkgs, pkgs-stable, ... }:`；stable 通道包用 `pkgs-stable.` 前缀。
- **NixOS 路径必须保持等价**：改造后 `sudo nixos-rebuild switch --flake .#nixos` 的系统效果与改造前一致；不剥离 `modules/programs.nix` 现有条目（避免破坏在用系统）。
- 非 NixOS 侧**纯 CLI、零 GUI**；不做系统层管理（不用 nix-darwin）。
- 支持平台：`x86_64-linux`（立即，覆盖 NixOS/WSL/普通 Linux）+ `aarch64-darwin`（仅结构预留，eval-only 验证，不要求 build）。
- 仓库根：`/home/xuqihao/nixos-niri-noctalia`（所有路径相对仓库根）。`modules/` 下 `.nix` 由 flake 自动加载。
- 验证命令在用户本机（已 warm 的 nix store）运行；优先用 eval-only 快速检查，最终任务做真实 build。

## 文件结构（本次创建/修改）

| 文件 | 动作 | 职责 |
|---|---|---|
| `packages/cli-dev.nix` | 新建 | 共享 CLI 工具列表（纯函数 → `[ pkgs ]`），单一事实源 |
| `modules/programs.nix` | 修改（1 行） | `environment.systemPackages` 末尾追加 `++ (import ../packages/cli-dev.nix)` |
| `home/common.nix` | 新建 | 跨平台 CLI-only HM 配置（从现 `home/default.nix` 抽取便携部分） |
| `home/default.nix` | 修改 | 改为 thin 入口：`imports = [ ./common.nix ];` + GUI HM + kitty/wezterm dotfiles + 用户信息 |
| `home/standalone.nix` | 新建 | 非 NixOS 入口：`imports = [ ./common.nix ];` + `home.packages = import ../packages/cli-dev.nix` |
| `flake.nix` | 修改 | 参数化 system、`forAllSystems`、`pkgsFor`、新增 `homeConfigurations.xuqihao` 与 `xuqihao-darwin` |
| `bootstrap/linux.sh` | 新建 | fresh Linux/WSL 一键装 Nix + 激活 HM |
| `home/nixvim.nix`、`home/fastfetch.nix`、`configuration.nix`、`hardware-configuration.nix`、其余 modules、`dotfiles/` | 不动 | — |

依赖顺序：Task 1 → Task 2；Task 3 → Task 4 & Task 5；Task 5 → Task 6；Task 6 → Task 7 & Task 8。

---

### Task 1: 创建共享 CLI 工具列表 `packages/cli-dev.nix`

**Files:**
- Create: `packages/cli-dev.nix`

**Interfaces:**
- Produces: 一个 Nix 函数 `{ pkgs, pkgs-stable, ... }: [ ... ]`，返回 package list。被 Task 2（programs.nix）和 Task 5（standalone.nix）以 `import ../packages/cli-dev.nix { inherit pkgs pkgs-stable; }` 调用。

- [ ] **Step 1: 创建 `packages/` 目录与文件**

写入 `packages/cli-dev.nix`：

```nix
# packages/cli-dev.nix
#
# 共享 CLI 开发工具列表 —— 纯函数，返回 package list。
# 单一事实源，被两处导入：
#   - modules/programs.nix   → NixOS 的 environment.systemPackages（系统级、sudo 可见）
#   - home/standalone.nix    → 非 NixOS 的 home.packages（用户级）
#
# 只放"无需 HM 托管 dotfile 的纯命令行工具"。
# 需要 dotfile 配置的（git/bash/starship/helix/ssh/nixvim/fastfetch）见 home/common.nix。
{ pkgs, pkgs-stable, ... }:

with pkgs; [
  # --- 现代基础 CLI ---
  ripgrep
  fd
  sd
  dust
  procs
  bottom
  btop
  tree
  tealdeer
  glow
  gh
  lazygit

  # --- 文件 / 会话 ---
  yazi
  eza
  zellij
  tmux

  # --- 开发工具链（稳定通道） ---
  pkgs-stable.gcc
  pkgs-stable.gnumake
  pkgs-stable.cmake
  pkgs-stable.ninja
  pkgs-stable.clang
  pkgs-stable.clang-tools
  pkgs-stable.gdb
  pkgs-stable.pkg-config
  pkgs-stable.rustc
  pkgs-stable.cargo
  pkgs-stable.go
  pkgs-stable.gopls
  pkgs-stable.delve
  pkgs-stable.nodejs
  pkgs-stable.jq
  pkgs-stable.python3

  # --- Nix 工具 ---
  nil
  nixpkgs-fmt

  # --- 排版（便携 CLI） ---
  typst
  tinymist
  typstyle

  # --- 小众 / 网络 CLI ---
  yt-dlp
  pkgs-stable.sshfs
  pkgs-stable.wget
  pkgs-stable.curl
  pkgs-stable.aria2
]
```

- [ ] **Step 2: 语法校验**

Run: `nix-instantiate --parse packages/cli-dev.nix > /dev/null && echo OK`
Expected: 输出 `OK`（仅语法解析；函数体在 Task 2/5 被 import 时才真正求值）。

- [ ] **Step 3: 提交**

```bash
git add packages/cli-dev.nix
git commit -m "feat: add shared CLI dev package list (packages/cli-dev.nix)"
```

---

### Task 2: 把 `cli-dev.nix` 接入 `modules/programs.nix`（NixOS 系统级）

**Files:**
- Modify: `modules/programs.nix`（仅 `environment.systemPackages` 那一处末尾）

**Interfaces:**
- Consumes: Task 1 的 `packages/cli-dev.nix`。
- Produces: NixOS 的 `environment.systemPackages` 现在包含共享 CLI 工具（→ `/run/current-system/sw/bin` → sudo 可见）。

- [ ] **Step 1: 在 `environment.systemPackages` 列表后追加 import**

定位 `modules/programs.nix` 中 `environment.systemPackages = with pkgs; [ ... ];` 块的**闭合 `];`**（位于 `pkgs-stable.readest` 之后、`nixpkgs.overlays` 之前，约第 314 行）。把：

```nix
    # --- 27. 其他工具 ---
    pkgs-stable.copyq
    pkgs-stable.uget
    howdy
    pkgs-stable.readest
  ];
```

改为：

```nix
    # --- 27. 其他工具 ---
    pkgs-stable.copyq
    pkgs-stable.uget
    howdy
    pkgs-stable.readest
  ]
  # 共享 CLI 开发工具（与 home/standalone.nix 同源；系统级安装使 sudo 可见）
  ++ (import ../packages/cli-dev.nix { inherit pkgs pkgs-stable; });
```

> 不要改动该文件其余任何内容（尤其保留末尾的 `nixpkgs.overlays = [ ... ]` wechat 覆盖块）。

- [ ] **Step 2: 校验 flake 仍可求值**

Run: `nix flake show --all-systems 2>&1 | head -20`
Expected: 列出 `nixosConfigurations` 等输出，无错误。（此时 `homeConfigurations` 尚未添加，属正常。）

- [ ] **Step 3: 校验 NixOS 配置可求值（eval-only，快速）**

Run: `nix eval .#nixosConfigurations.nixos.config.system.build.toplevel.drvPath 2>&1 | tail -5`
Expected: 输出一个 `/nix/store/...-nixos-system-nixos-....drv` 路径，无错误。确认追加 import 未破坏 NixOS 求值。

- [ ] **Step 4: 提交**

```bash
git add modules/programs.nix
git commit -m "feat(nixos): wire shared cli-dev list into environment.systemPackages"
```

---

### Task 3: 抽取便携 HM 配置到 `home/common.nix`

**Files:**
- Create: `home/common.nix`

**Interfaces:**
- Consumes: `inputs.nixvim.homeModules.nixvim`、`./nixvim.nix`、`./fastfetch.nix`（均现存）。
- Produces: 一个 HM 模块，含 `programs.git/bash/starship/helix/ssh`、nixvim、fastfetch、便携 dotfiles（`.config/btop`）。**不设置** `home.username/homeDirectory/stateVersion`（由入口文件注入）。被 Task 4（`home/default.nix`）与 Task 5（`home/standalone.nix`）`imports`。

- [ ] **Step 1: 写入 `home/common.nix`**

```nix
# home/common.nix
#
# 跨平台、纯 CLI 的 Home Manager 核心配置。
# 被 home/default.nix（NixOS）与 home/standalone.nix（非 NixOS）共同导入。
# 零 GUI 假设：NixOS / WSL / 普通 Linux / macOS 均可运行。
{ config, pkgs, pkgs-stable, inputs, ... }:

{
  imports = [
    inputs.nixvim.homeModules.nixvim
    ./nixvim.nix
    ./fastfetch.nix
  ];

  # --- 1. Git ---
  programs.git = {
    enable = true;
    settings = {
      user.name = "xuqihao";
      user.email = "xuqihao@ihep.ac.cn";
    };
  };

  # --- 2. Bash ---
  programs.bash = {
    enable = true;
    enableCompletion = true;
    bashrcExtra = ''
      export PATH="$PATH:$HOME/bin:$HOME/.local/bin:$HOME/go/bin"
    '';
    shellAliases = {
      ll = "eza -l --icons";
      lt = "eza -lT --icons";
      la = "eza -la --icons";
      nrs = "sudo nixos-rebuild switch";
      nrrs = "sudo nix-channel --update && sudo nixos-rebuild switch";
      shh = "ssh xuqihao@lxlogin.ihep.ac.cn";
      shhfs = "sshfs -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3 xuqihao@lxlogin.ihep.ac.cn:/ ~/mnt/juno/";
      afs = "cd ~/mnt/juno/afs/ihep.ac.cn/users/x/xuqihao";
      scratchfs = "cd ~/mnt/juno/scratchfs/juno/xuqihao";
      junofs = "cd ~/mnt/juno/junofs/users/xuqihao";
      workfs = "cd ~/mnt/juno/workfs2/juno/xuqihao";
      archbox = "distrobox enter archbox";
      susebox = "distrobox enter susebox";
      fedorabox = "distrobox enter fedorabox";
      kalibox = "distrobox enter kalibox";
      debianbox = "distrobox enter debianbox";
      root = "root -l";
    };
  };

  # --- 3. Starship 提示符 ---
  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      aws.disabled = true;
      gcloud.disabled = true;
    };
    presets = [ "gruvbox-rainbow" ];
  };

  # --- 4. Helix 编辑器 ---
  programs.helix = {
    enable = true;
    settings = {
      theme = "base16_transparent";
    };
  };

  # --- 5. SSH ---
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "juno" = {
        hostname = "lxlogin.ihep.ac.cn";
        user = "xuqihao";
        port = 22;
      };
    };
  };

  # --- 6. 便携 dotfiles（GUI 终端配置不在此） ---
  home.file = {
    ".config/btop" = {
      source = ../dotfiles/.config/btop;
      recursive = true;
    };
  };
}
```

> 说明：原 `home/default.nix` 中 `programs.vim`（`enable = false`）已禁用，故不迁移；alacritty/ghostty/fuzzel/xsettingsd/kitty/wezterm 是 GUI，留 Task 4 的 NixOS 入口。

- [ ] **Step 2: 语法校验**

Run: `nix-instantiate --parse home/common.nix > /dev/null && echo OK`
Expected: 输出 `OK`。

- [ ] **Step 3: 提交**

```bash
git add home/common.nix
git commit -m "refactor(home): extract portable CLI config into home/common.nix"
```

---

### Task 4: 把 `home/default.nix` 改为 thin NixOS 入口

**Files:**
- Modify: `home/default.nix`（整体替换为 thin 入口）

**Interfaces:**
- Consumes: Task 3 的 `home/common.nix`。
- Produces: NixOS 模式下 `home-manager.users.xuqihao` 导入的模块 = common + GUI HM + kitty/wezterm dotfiles + 用户信息。行为与改造前一致。

- [ ] **Step 1: 用以下内容整体替换 `home/default.nix`**

```nix
# home/default.nix
#
# NixOS 模式下的 Home Manager 入口（作为 home-manager.users.<user> 导入）。
# = common（便携 CLI 核心）+ GUI HM 模块（仅 NixOS 桌面）+ GUI 终端 dotfiles + 用户信息。
{ config, pkgs, pkgs-stable, inputs, ... }:

{
  imports = [
    ./common.nix
  ];

  # 用户信息（NixOS 固定）
  home = {
    username = "xuqihao";
    homeDirectory = "/home/xuqihao";
    stateVersion = "26.05";
  };

  # --- GUI 终端（仅 NixOS 桌面；非 NixOS 由原生系统负责） ---
  programs.alacritty = {
    enable = true;
    settings = {
      font = {
        size = 12.0;
        bold = { family = "JetBrains Mono"; style = "Heavy"; };
        italic = { family = "JetBrains Mono"; style = "Medium Italic"; };
        bold_italic = { family = "JetBrains Mono"; style = "Heavy"; };
        normal = { family = "JetBrains Mono"; style = "Medium"; };
      };
      window = {
        decorations = "Full";
        dynamic_padding = false;
        opacity = 0.9;
      };
      scrolling = {
        history = 1000;
        multiplier = 5;
      };
      selection = {
        save_to_clipboard = true;
      };
    };
  };

  programs.ghostty = {
    enable = true;
    settings = {
      theme = "TokyoNight";
      background-opacity = "0.9";
    };
  };

  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "JetBrains Mono 12";
      };
      colors = {
        background = "#000000cc";
        text = "ffffffff";
      };
    };
  };

  services.xsettingsd = {
    enable = true;
    settings = {
      "Gtk/CursorThemeName" = "Bibata-Modern-Blue";
      "Gtk/CursorThemeSize" = 24;
      "Gtk/FontName" = "JetBrains Mono 24";
      "Gtk/WindowScalingFactor" = 2;
      "Xft/Antialias" = 1;
      "Xft/Hinting" = 1;
      "Xft/HintStyle" = "hintfull";
      "Xft/RGBA" = "rgb";
      "Xft/DPI" = 196608;
    };
  };

  # --- GUI 终端 dotfiles（仅 NixOS） ---
  home.file = {
    ".config/kitty" = {
      source = ../dotfiles/.config/kitty;
      recursive = true;
    };
    ".config/wezterm" = {
      source = ../dotfiles/.config/wezterm;
      recursive = true;
    };
  };
}
```

- [ ] **Step 2: 校验 NixOS home 配置可求值**

Run: `nix eval .#nixosConfigurations.nixos.config.home-manager.users.xuqihao.home.homeDirectory 2>&1 | tail -3`
Expected: 输出 `"/home/xuqihao"`，无错误。确认 default.nix 重构后 NixOS home 仍正常求值。

- [ ] **Step 3: 提交**

```bash
git add home/default.nix
git commit -m "refactor(home): slim home/default.nix to NixOS entry importing common.nix"
```

---

### Task 5: 创建非 NixOS 入口 `home/standalone.nix`

**Files:**
- Create: `home/standalone.nix`

**Interfaces:**
- Consumes: Task 3 的 `home/common.nix`、Task 1 的 `packages/cli-dev.nix`。
- Produces: 非 NixOS 模式 HM 模块 = common + 共享 CLI 工具（`home.packages`）。`home.username/homeDirectory/stateVersion` 由 Task 6 的 flake `mkStandaloneHome` 注入（不在本文件设置）。

- [ ] **Step 1: 写入 `home/standalone.nix`**

```nix
# home/standalone.nix
#
# 非 NixOS 模式下的 Home Manager 入口（Linux / WSL / macOS 通用）。
# = common（便携 CLI 核心）+ 共享 CLI 工具（home.packages）。
# 零 GUI。home.username / homeDirectory / stateVersion 由 flake 的 mkStandaloneHome 注入。
{ config, pkgs, pkgs-stable, inputs, ... }:

{
  imports = [
    ./common.nix
  ];

  # 共享 CLI 开发工具（用户级安装；与 NixOS 的 programs.nix 同源）
  home.packages = import ../packages/cli-dev.nix {
    inherit pkgs pkgs-stable;
  };
}
```

- [ ] **Step 2: 语法校验**

Run: `nix-instantiate --parse home/standalone.nix > /dev/null && echo OK`
Expected: 输出 `OK`。

- [ ] **Step 3: 提交**

```bash
git add home/standalone.nix
git commit -m "feat(home): add standalone (non-NixOS) entry home/standalone.nix"
```

---

### Task 6: 改造 `flake.nix`：参数化 system + 新增 `homeConfigurations`

**Files:**
- Modify: `flake.nix`（整体替换）

**Interfaces:**
- Consumes: Task 5 的 `home/standalone.nix`、`home-manager.lib.homeManagerConfiguration`。
- Produces: `nixosConfigurations.nixos`（等价不变）、`homeConfigurations.xuqihao`（x86_64-linux）、`homeConfigurations.xuqihao-darwin`（aarch64-darwin，预留）。

- [ ] **Step 1: 用以下内容整体替换 `flake.nix`**

```nix
{
  description = "NixOS configuration + portable Home Manager CLI environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nix-26.05";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";

    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # --- NixVim (声明式 Neovim 配置) ---
    nixvim = {
      url = "github:nix-community/nixvim/nixos-26.05";
    };

    # --- Chaotic AUR 源 ---
    chaotic = {
      url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-stable,
      home-manager,
      hermes-agent,
      chaotic,
      ...
    }@inputs:
    let
      # 支持的 system 列表
      supportedSystems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);

      # 按 system 实例化 stable / master
      pkgsFor = system: {
        stable = import nixpkgs-stable {
          inherit system;
          config.allowUnfree = true;
          config.permittedInsecurePackages = [ "electron-38.8.4" ];
        };
        master = import inputs.nixpkgs-master {
          inherit system;
          config.allowUnfree = true;
        };
      };

      # NixOS 仍固定 x86_64-linux
      nixosSystem = "x86_64-linux";
      nixosPkgs = pkgsFor nixosSystem;

      # 自动扫描 modules 目录下的所有 .nix 文件
      configDir = ./modules;
      generatedModules = builtins.map (file: configDir + "/${file}") (
        builtins.filter (file: nixpkgs.lib.hasSuffix ".nix" file) (
          builtins.attrNames (builtins.readDir configDir)
        )
      );

      # 构造 standalone home-manager 配置（非 NixOS）
      mkStandaloneHome = {
        system,
        homeDirectory,
        username ? "xuqihao",
      }:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          config.permittedInsecurePackages = [ "electron-38.8.4" ];
        };
        extra = pkgsFor system;
      in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            inherit inputs;
            pkgs-stable = extra.stable;
            pkgs-master = extra.master;
          };
          modules = [
            ./home/standalone.nix
            {
              home = {
                inherit username homeDirectory;
                stateVersion = "26.05";
              };
            }
          ];
        };
    in
    {
      # --- 1. NixOS 系统配置（x86_64-linux，行为不变） ---
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = nixosSystem;
        specialArgs = {
          inherit inputs;
          pkgs-stable = nixosPkgs.stable;
          pkgs-master = nixosPkgs.master;
        };
        modules = [
          ./configuration.nix
          home-manager.nixosModules.home-manager
          chaotic.nixosModules.default
          inputs.hermes-agent.nixosModules.default
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.xuqihao = import ./home/default.nix;

            home-manager.extraSpecialArgs = {
              inherit inputs;
              pkgs-stable = nixosPkgs.stable;
              pkgs-master = nixosPkgs.master;
            };
          }
        ] ++ generatedModules;
      };

      # --- 2. 非 NixOS 便携 CLI 环境（Home Manager standalone, x86_64-linux） ---
      homeConfigurations.xuqihao = mkStandaloneHome {
        system = "x86_64-linux";
        homeDirectory = "/home/xuqihao";
      };

      # --- 3. macOS 预留（aarch64-darwin，仅结构就绪，未实测 build） ---
      homeConfigurations.xuqihao-darwin = mkStandaloneHome {
        system = "aarch64-darwin";
        homeDirectory = "/Users/xuqihao";
      };
    };
}
```

- [ ] **Step 2: 校验 flake 结构（eval-only，快速）**

Run: `nix flake show --all-systems 2>&1 | grep -E 'homeConfigurations|nixosConfigurations'`
Expected: 看到 `homeConfigurations.xuqihao`、`homeConfigurations.xuqihao-darwin`、`nixosConfigurations.nixos`，无错误。

- [ ] **Step 3: 校验 standalone (Linux) 可求值**

Run: `nix eval .#homeConfigurations.xuqihao.activationPackage.drvPath 2>&1 | tail -3`
Expected: 输出一个 `/nix/store/...-home-manager-generation.drv` 路径，无错误。若报某包名不存在，按报错调整 `packages/cli-dev.nix` 对应条目（`pkgs`↔`pkgs-stable`）后重跑。

- [ ] **Step 4: 校验 darwin 预留可求值（eval-only，本机无法 build darwin）**

Run: `nix eval .#homeConfigurations.xuqihao-darwin.activationPackage.drvPath 2>&1 | tail -3`
Expected: 输出一个 `.drv` 路径，无错误。若个别 darwin 不可用包报错，记录到下方备注并在 `home/standalone.nix` 或 `common.nix` 用 `lib.mkIf` 暂时跳过（属预留阶段的可接受结果）。

- [ ] **Step 5: 提交**

```bash
git add flake.nix
git commit -m "feat(flake): parameterize system, add homeConfigurations (xuqihao + darwin reserve)"
```

---

### Task 7: 创建 `bootstrap/linux.sh`

**Files:**
- Create: `bootstrap/linux.sh`

**Interfaces:**
- Consumes: Task 6 的 `homeConfigurations.xuqihao`。
- Produces: 一个 bash 脚本，在干净 Linux/WSL 上装 Nix + 激活 HM。

- [ ] **Step 1: 写入 `bootstrap/linux.sh`**

```bash
#!/usr/bin/env bash
# bootstrap/linux.sh
#
# 在一台干净的 Linux / WSL 上搭建 Nix + Home Manager 便携 CLI 环境。
# 前置：已 git clone 本仓库，并在仓库根目录运行：  bash bootstrap/linux.sh
# 可选参数：第一个参数为 flake target，默认 xuqihao。
set -euo pipefail

# 切到仓库根（脚本位于 bootstrap/ 下）
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

FLAKE_TARGET="${1:-xuqihao}"

echo "==> 1/2 安装 Nix（Determinate Systems 安装器，默认开启 flakes）"
if ! command -v nix >/dev/null 2>&1; then
  curl -fsSL https://install.determinate.systems/nix | sh -s -- install
  # 加载 nix 环境变量
  for f in \
    /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
    "$HOME/.nix-profile/etc/profile.d/nix.sh"; do
    [ -f "$f" ] && . "$f" && break
  done
else
  echo "    nix 已安装，跳过"
fi

echo "==> 2/2 激活 Home Manager（flake target: ${FLAKE_TARGET}）"
nix run "github:nix-community/home-manager" -- switch --flake ".#${FLAKE_TARGET}"

echo "==> 完成。重新打开 shell（或 source ~/.bashrc）以加载新环境。"
```

- [ ] **Step 2: 加可执行位 + 语法校验**

Run: `chmod +x bootstrap/linux.sh && bash -n bootstrap/linux.sh && echo OK`
Expected: 输出 `OK`。

- [ ] **Step 3: shellcheck（若可用）**

Run: `command -v shellcheck >/dev/null && shellcheck bootstrap/linux.sh || echo "shellcheck 不可用，跳过"`
Expected: 无严重错误（info 级提示可忽略）。

- [ ] **Step 4: 提交**

```bash
git add bootstrap/linux.sh
git commit -m "feat(bootstrap): add linux/WSL one-shot Nix + Home Manager bootstrap script"
```

---

### Task 8: 最终集成验证

**Files:** 无新增/修改（仅验证）。

**Interfaces:** 消费 Task 1–7 全部产出。

- [ ] **Step 1: NixOS 配置真实 build（不切换），确认系统路径完好**

Run: `nixos-rebuild build --flake .#nixos 2>&1 | tail -10`
Expected: 成功生成 system profile（`/nix/store/...-nixos-system-nixos-...`），无错误。确认 NixOS 路径未被破坏。

- [ ] **Step 2: standalone (Linux) 真实 build**

Run: `nix build .#homeConfigurations.xuqihao.activationPackage --print-out-paths 2>&1 | tail -5`
Expected: 输出一个 `/nix/store/...-home-manager-generation` 路径，无错误。确认非 NixOS 便携环境可在 x86_64-linux 上 build。

- [ ] **Step 3: 抽查 sudo 关心的 CLI 工具确实进入系统级**

Run: `nixos-rebuild dry-build --flake .#nixos 2>&1 | grep -iE 'ripgrep|gcc|hx' | head -5` 或直接 `command -v rg && command -v gcc`
Expected: `rg`、`gcc` 等存在/可见（在已 switch 的系统上；本步主要确认 Task 2 的接入生效）。

- [ ] **Step 4: darwin 预留 eval 复核（不 build）**

Run: `nix eval .#homeConfigurations.xuqihao-darwin.activationPackage.drvPath 2>&1 | tail -2`
Expected: 输出 `.drv` 路径，无错误（与 Task 6 Step 4 一致）。

- [ ] **Step 5: 总结提交（若有零散调整）**

仅在前面步骤为通过而做了小修补时执行：

```bash
git add -A
git commit -m "chore: integration fixes for dual-mode flake"
```

---

## 备注

- **`xuqihao-darwin` 未实测 build**：本机为 x86_64-linux，无法 build darwin；仅以 `nix eval ...drvPath`（eval-only）作为预留验证。真正上 Mac 时按需追加 Mac 专属 CLI（如 `coreutils`、`reattach-to-user-namespace`）。
- **programs.nix 未去重**：为安全起见未剥离现有条目，CLI 工具在 NixOS 上可能同时存在于 programs.nix 与 cli-dev.nix（store 去重，无开销）。去重可作为后续可选清理。
- **nixvim / fastfetch 跨平台**：二者在 darwin 上的可用性以实际 eval 结果为准；若 Task 6 Step 4 报错，按报错用 `lib.mkIf` 在 common.nix 内平台条件化。
