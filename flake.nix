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
      # 本地用户名单点定义：换用户名只改这一行。
      # NixOS users.users.*、home-manager.users.*、standalone 输出名（.#xuqihao / .#xuqihao-darwin）
      # 与 hms 别名目标均由它派生；远程身份（IHEP 账号、git 邮箱）在 home/common.nix，需单独调整。
      username = "xuqihao";

      # 支持的 system 列表
      supportedSystems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);

      # 按 system 实例化 stable
      pkgsFor = system: {
        stable = import nixpkgs-stable {
          inherit system;
          config.allowUnfree = true;
          config.permittedInsecurePackages = [ "electron-38.8.4" ];
        };
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
          inherit inputs username;
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
            inherit inputs username;
            isStandalone = true;
            pkgs-stable = extra.stable;
          };
          modules = [
            standaloneModule
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
          inherit inputs username;
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
          inherit inputs username;
          pkgs-stable = nixosPkgs.stable;
        };
        modules = [
          inputs.nixos-wsl.nixosModules.default
          ./hosts/wsl
          home-manager.nixosModules.home-manager
          (nixosHome ./home/nixos-cli.nix)
        ];
      };

      # --- 2. 非 NixOS 便携 CLI 环境（Home Manager standalone, x86_64-linux） ---
      homeConfigurations.${username} = mkStandaloneHome {
        system = "x86_64-linux";
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
