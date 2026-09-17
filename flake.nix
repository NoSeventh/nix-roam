{
  description = "NixOS configuration + portable Home Manager CLI environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";

    # zen-browser = {
    #   url = "github:youwen5/zen-browser-flake";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    # quickshell = {
    #   url = "git+https://git.outfoxxed.me/quickshell/quickshell";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    # dms = {
    #   url = "github:AvengeMedia/DankMaterialShell";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    # noctalia = {
    #   url = "github:noctalia-dev/noctalia-shell";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
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

  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-stable,
      home-manager,
      hermes-agent,
      ...
    }@inputs:
    let
      # 本地用户名单点定义：仓库根 meta.json（bootstrap 脚本在装 Nix 之前也要读，不能只放 Nix 表达式里）。
      # 换用户名只改 meta.json 一行。NixOS users.users.*、home-manager.users.*、standalone 输出名
      # （.#xuqihao / .#xuqihao-aarch64 / .#xuqihao-darwin）与 hms 别名目标均由它派生；
      # 远程身份（IHEP 账号、git 邮箱）在 home/common.nix，需单独调整。
      username = (builtins.fromJSON (builtins.readFile ./meta.json)).username;

      # 共享 stateVersion 单点定义（home.stateVersion 与 system.stateVersion 同值）；
      # 被采纳的老主机可在 hosts/<hostname>/ 入口用 mkForce 保留原值。
      stateVersion = "26.05";

      # unstable / stable 实例共用的 nixpkgs config。NixOS unstable 实例的 insecure 列表另在
      # profiles/nixos-base.nix 声明 —— 那是另一实例的刻意差异，不做合并扩权。
      # （2026-09-17 验证后移除了此处的 electron-38.8.4：五个输出求值 + standalone 构建均不引用；
      #   若日后 lock 更新再次需要，在此重新添加即可。）
      nixpkgsConfig = {
        allowUnfree = true;
      };

      # 按 system 实例化 unstable 与 stable
      pkgsFor = system: {
        unstable = import nixpkgs { inherit system; config = nixpkgsConfig; };
        stable = import nixpkgs-stable { inherit system; config = nixpkgsConfig; };
      };

      # NixOS 仍固定 x86_64-linux
      nixosSystem = "x86_64-linux";
      nixosPkgs = pkgsFor nixosSystem;

      # Shared NixOS Home Manager integration; each host selects its user profile.
      nixosHome = homeModule: {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.users.${username} = import homeModule;
        home-manager.extraSpecialArgs = {
          inherit inputs username stateVersion;
          isStandalone = false;
          pkgs-stable = nixosPkgs.stable;
        };
      };

      # 构造 standalone home-manager 配置（非 NixOS）
      mkStandaloneHome = {
        system,
        homeDirectory,
        standaloneModule ? ./home/standalone-linux.nix,
      }:
      let
        channels = pkgsFor system;
      in
        home-manager.lib.homeManagerConfiguration {
          pkgs = channels.unstable;
          extraSpecialArgs = {
            inherit inputs username;
            isStandalone = true;
            pkgs-stable = channels.stable;
          };
          modules = [
            standaloneModule
            {
              home = {
                inherit username homeDirectory stateVersion;
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
          inherit inputs username stateVersion;
          pkgs-stable = nixosPkgs.stable;
        };
        # Host entry hosts/nixos pulls in profiles/desktop.nix, which imports
        # the explicit desktop module list under modules/desktop/.
        modules = [
          ./hosts/nixos
          home-manager.nixosModules.home-manager
          inputs.hermes-agent.nixosModules.default
          (nixosHome ./home/default.nix)
        ];
      };

      # NixOS-WSL: host entry hosts/wsl imports shared profiles explicitly.
      nixosConfigurations.wsl = nixpkgs.lib.nixosSystem {
        system = nixosSystem;
        specialArgs = {
          inherit inputs username stateVersion;
          pkgs-stable = nixosPkgs.stable;
        };
        modules = [
          inputs.nixos-wsl.nixosModules.default
          ./hosts/wsl
          home-manager.nixosModules.home-manager
          (nixosHome ./home/nixos-cli.nix)
        ];
      };

      # --- 2. 非 NixOS 便携 CLI 环境（Home Manager standalone，Linux 双架构显式输出） ---
      homeConfigurations.${username} = mkStandaloneHome {
        system = "x86_64-linux";
        homeDirectory = "/home/${username}";
      };

      # aarch64 Linux（ARM SBC / Asahi 等）：同一入口模块、同一包列表，仅 system 不同。
      # 共享列表的 Linux-only 包已在锁定 rev 上确认 aarch64-linux 可用（root 非 broken、在 platforms 内）。
      homeConfigurations."${username}-aarch64" = mkStandaloneHome {
        system = "aarch64-linux";
        homeDirectory = "/home/${username}";
      };

      # --- 3. macOS 预留（aarch64-darwin，仅结构就绪，未实测 build） ---
      homeConfigurations."${username}-darwin" = mkStandaloneHome {
        system = "aarch64-darwin";
        homeDirectory = "/Users/${username}";
        standaloneModule = ./home/standalone-darwin.nix;
      };
    };
}
