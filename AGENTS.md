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
- `nixpkgs` (unstable) - For packages that need to stay updated (browsers, AI tools, editors)
- `nixpkgs-stable` (25.11) - For stable packages that don't need frequent updates
- `nixpkgs-master` - Available but not actively used

### Using pkgs-stable

When adding packages to modules, decide which channel to use:

**Use `pkgs` (unstable) for:**
- AI-related tools: claude-code, codex, gemini-cli, opencode-desktop, cherry-studio
- Browsers: firefox, chromium, google-chrome
- Modern editors: vscode, zed-editor, code-cursor, neovim
- Proxy tools: clash-verge-rev, sing-box, v2rayn (need latest rules)
- Chinese software: qq, wechat-uos, obsidian

**Use `pkgs-stable` for:**
- Large desktop apps: libreoffice, thunderbird, calibre
- Media players: vlc, mpv, gimp, blender
- Development toolchains: gcc, clang, rustc, go
- System tools: git, tmux, btop, fd, bat
- Fonts and input methods
- JetBrains IDEs

**Example:**
```nix
{ config, pkgs, pkgs-stable, ... }:

{
  environment.systemPackages = with pkgs; [
    # Unstable packages (need latest)
    firefox
    vscode
    claude-code
    
    # Stable packages (use pkgs-stable prefix)
    pkgs-stable.libreoffice
    pkgs-stable.vlc
    pkgs-stable.git
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
  firefox                    # unstable
  pkgs-stable.libreoffice    # stable
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
├── flake.nix                 # Entry point, defines pkgs-stable
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

## Important Notes

- **No linting/formatting tools configured** - maintain consistent 2-space indentation manually
- **No testing framework** - verify by rebuilding and checking system behavior
- **Hardware-specific config** (`hardware-configuration.nix`) should not be committed (see .gitignore)
- **Flake-based**: Always work within the flake context - use `inputs` for external packages
- **Chinese locale**: System configured for zh_CN.UTF-8 with Fcitx5 input method
- **Niri WM**: Primary Wayland compositor (with Hyprland and Sway as fallbacks)
- **Virtualization**: Both Docker and Podman enabled - do not enable both for the same containers
- **Dual-channel**: Remember to use `pkgs-stable.` prefix for packages that should use the stable channel
