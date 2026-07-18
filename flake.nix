{
  description = "NixOS configuration + portable Home Manager CLI environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";

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
            inherit inputs;
            pkgs-stable = extra.stable;
            pkgs-master = extra.master;
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
        standaloneModule = ./home/standalone-darwin.nix;
      };
    };
}
