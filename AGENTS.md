# AGENTS.md

This repository contains a NixOS system configuration using flakes. Agents working here must understand Nix package management and declarative configuration.

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

## Code Style Guidelines

### Nix Language

**Function signatures:** Always use ellipsis (`...`) for attribute sets to handle future parameter expansion:
```nix
{ config, pkgs, inputs, lib, ... }:
```

**Indentation:** 2 spaces (Nix standard)

**Section organization:** Use numbered sections with dividers:
```nix
# --- 1. Section Name ---
# --- 2. Another Section ---
```

**Comments:** Mix of English and Chinese comments is acceptable. Comment disabled code rather than deleting it.

**Package lists:** Use `with pkgs; [ ... ]` pattern:
```nix
environment.systemPackages = with pkgs; [
  vim
  neovim
  git
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
├── flake.nix                 # Entry point, auto-loads modules/
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
│   ├── programs-headless.nix # CLI tools, dev tools
│   ├── programs.nix         # GUI applications
│   └── virtualization.nix   # Docker, Podman, libvirt
└── dotfiles/               # User config files (terminals, themes)
```

### Configuration Patterns

**Module imports:** Use relative paths for imports in `configuration.nix`:
```nix
imports = [
  ./hardware-configuration.nix
];
```

**Auto-loading:** The `flake.nix` automatically loads all `.nix` files from `modules/` directory.

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
  after = [ "network-online.target" ];
  wantedBy = [ "default.target" ];
  serviceConfig = { ... };
};
```

## Important Notes

- **No linting/formatting tools configured** - maintain consistent 2-space indentation manually
- **No testing framework** - verify by rebuilding and checking system behavior
- **Hardware-specific config** (`hardware-configuration.nix`) should not be committed
- **Flake-based**: Always work within the flake context - use `inputs` for external packages
- **Chinese locale**: System configured for zh_CN.UTF-8 with Fcitx5 input method
- **Niri WM**: Primary Wayland compositor (with Hyprland and Sway as fallbacks)
- **Virtualization**: Both Docker and Podman enabled - do not enable both for the same containers
