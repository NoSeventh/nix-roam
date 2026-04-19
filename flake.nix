{
  description = "NixOS configuration with auto-module loading";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
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

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # --- 3. NixVim (声明式Neovim配置) ---
    nixvim = {
      url = "github:nix-community/nixvim/nixos-25.11";
    };

    # --- 4. Chaotic AUR 源 ---
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
      chaotic,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      # 定义 stable 包的快捷方式，并开启 allowUnfree 和 permittedInsecurePackages
      pkgs-stable = import nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
        config.permittedInsecurePackages = [
          "electron-38.8.4"
        ];
      };
      # 自动扫描 modules 目录下的所有 .nix 文件
      configDir = ./modules;
      generatedModules = builtins.map (file: configDir + "/${file}") (
        builtins.filter (file: nixpkgs.lib.hasSuffix ".nix" file) (
          builtins.attrNames (builtins.readDir configDir)
        )
      );
    in
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs pkgs-stable; };
        modules = [
          ./configuration.nix
          home-manager.nixosModules.home-manager
          chaotic.nixosModules.default # 从 chaotic 源导入模块
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.xuqihao = import ./home/default.nix;

            # 使用 home-manager.extraSpecialArgs 自定义传递给 ./home.nix 的参数
            # 取消注释下面这一行，就可以在 home.nix 中使用 flake 的所有 inputs 参数了
            home-manager.extraSpecialArgs = { inherit inputs pkgs-stable; };
          }
        ]
        ++ generatedModules;
      };
    };
}
