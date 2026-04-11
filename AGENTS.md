# AGENTS.md

This repository contains a NixOS system configuration using flakes with dual-channel package management (unstable + stable). Agents working here must understand Nix package management and declarative configuration.

## Build System

**Primary commands:**
```bash
# Apply system configuration
sudo nixos-rebuild switch

# Or use alias (defined in home.nix)
nrs

# Update channels and rebuild
nrrs
```

**Testing:** No automated test framework - this is system configuration, not application code.
Verify changes by rebuilding and checking system behavior after modifications.

## Dual-Channel Package Management

This configuration uses **three nixpkgs channels**:
- `nixpkgs` (unstable)
- `nixpkgs-stable` (25.11)
- `nixpkgs-master` - Available but not actively used

### Using pkgs-stable

When adding packages, use `pkgs-stable.` prefix for packages from the stable channel:

```nix
{ config, pkgs, pkgs-stable, ... }:

{
  environment.systemPackages = with pkgs; [
    # Browsers
    firefox
    pkgs-stable.chromium

    # Editors
    vscode
    pkgs-stable.neovim

    # Office
    pkgs-stable.libreoffice
    pkgs-stable.thunderbird

    # Media
    pkgs-stable.vlc
    pkgs-stable.mpv
  ];
}
```

## Code Style Guidelines

### Nix Language

**Function signatures:** Always use ellipsis (`...`) for attribute sets to handle future parameter expansion:
```nix
{ config, pkgs, pkgs-stable, inputs, lib, ... }:
```

**Indentation:** 2 spaces (Nix standard)

**Section organization:** Use numbered sections with dividers:
```nix
# --- 1. Section Name ---
# --- 2. Another Section ---
```

**Comments:** Mix of English and Chinese comments is acceptable. Comment disabled code rather than deleting it.

**Package lists:** Use `with pkgs; [ ... ]` pattern, prefix stable packages with `pkgs-stable.`:
```nix
environment.systemPackages = with pkgs; [
  firefox
  pkgs-stable.libreoffice
];
```

**Attribute sets:** No trailing comma on last element:
```nix
{
  enable = true;
  settings = { ... };
}
```

### File Structure

```
/home/xuqihao/nixos-niri-noctalia/
├── flake.nix                 # Entry point, defines pkgs-stable, inputs
├── configuration.nix         # System-level configuration
├── home.nix                 # User-level configuration (Home Manager)
├── hardware-configuration.nix # Hardware-specific (DO NOT commit changes)
├── modules/                 # Auto-loaded NixOS modules
│   ├── automation.nix       # Nix GC, optimization
│   ├── fix-network.nix      # Substituters, mirrors
│   ├── flatpak&linyaps-module.nix  # Flatpak, GNOME/KDE
│   ├── locale-zh.nix        # Chinese locale, fonts, input
│   ├── mnt.nix              # SSHFS mounts
│   ├── niri.nix             # Niri WM, compositor
│   ├── programs.nix         # GUI + CLI applications (merged)
│   └── virtualization.nix   # Docker, Podman, libvirt
└── dotfiles/               # User config files (terminals, themes)
```

### Configuration Patterns

**Adding pkgs-stable to modules:**
All modules that use packages must accept `pkgs-stable` parameter:
```nix
{ config, pkgs, pkgs-stable, ... }:  # Add pkgs-stable here
{
  environment.systemPackages = [
    pkgs-stable.some-package
  ];
}
```

**Module imports:** Use relative paths for imports in `configuration.nix`:
```nix
imports = [
  ./hardware-configuration.nix
];
```

**Auto-loading:** The `flake.nix` automatically loads all `.nix` files from `modules/` directory using `generatedModules` pattern.

**Home Manager:** User-level configuration lives in `home.nix`. Use `home.file` for dotfile management:
```nix
home.file.".config/nvim" = {
  source = ./dotfiles/.config/nvim;
  recursive = true;
};
```

**Systemd services:** Define services with clear descriptions:
```nix
systemd.services.my-service = {
  description = "Clear service description";
  startAt = "weekly";
  serviceConfig = {
    Type = "oneshot";
    User = "root";
    ExecStart = "...";
  };
};
```

## Handling EOL/Insecure Packages

Some Electron-based applications may depend on EOL (End-of-Life) Electron versions. If you see errors like:
```
Package 'electron-38.8.4' is EOL
```

The configuration already permits these packages in both channels:
- **flake.nix**: `pkgs-stable` has `permittedInsecurePackages` configured
- **configuration.nix**: Main nixpkgs has `permittedInsecurePackages` configured

To add new EOL packages, update **both** locations:
```nix
# In flake.nix (pkgs-stable)
pkgs-stable = import nixpkgs-stable {
  inherit system;
  config.allowUnfree = true;
  config.permittedInsecurePackages = [
    "electron-38.8.4"
    "electron-xx.x.x"  # Add new ones here
  ];
};

# In configuration.nix (unstable)
nixpkgs.config.permittedInsecurePackages = [
  "electron-38.8.4"
  "electron-xx.x.x"  # Add new ones here
];
```

## Flake Inputs

This repository uses several external flakes:

- **home-manager**: User configuration management
- **noctalia**: Custom shell (noctalia-shell)
- **dms**: DankMaterialShell (dms-shell)
- **quickshell**: Quick integration with DMS
- **chaotic**: Chaotic AUR source for additional packages

Access flake packages in modules using `inputs`:
```nix
{ config, pkgs, pkgs-stable, inputs, ... }:
{
  environment.systemPackages = with pkgs; [
    inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.quickshell
  ];
}
```

## Important Notes

- **No linting/formatting tools configured** - maintain consistent 2-space indentation manually
- **No testing framework** - verify by rebuilding and checking system behavior
- **Hardware-specific config** (`hardware-configuration.nix`) should not be committed (see .gitignore)
- **Flake-based**: Always work within the flake context - use `inputs` for external packages
- **Chinese locale**: System configured for zh_CN.UTF-8 with Fcitx5 input method
- **Niri WM**: Primary Wayland compositor (with Hyprland and Sway as fallbacks)
- **Virtualization**: Both Docker and Podman enabled - do not enable both for the same containers
- **Module auto-loading**: All `.nix` files in `modules/` are automatically loaded - no manual imports needed
- **Dual-channel**: Use `pkgs-stable.` prefix for packages from the stable channel - this distinction is important for package stability
