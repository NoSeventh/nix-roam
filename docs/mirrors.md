# 国内镜像与缓存（机制与考古）

规则（`meta.json` 单源、不得硬编码回落、脚本写入机制须两侧同步）在 [`AGENTS.md`](../AGENTS.md)「China mirrors」与「Quick rules」；本文承载运作细节与历史事件。内容系 2026-09-28 从 AGENTS.md 镜像节与 README 注意事项长注拆出（拆分记录见 [`VALIDATION.md`](VALIDATION.md)），措辞以搬运为主。

## CERNET 聚合器不可直接使用

`help.mirrors.cernet.edu.cn` (note the `s` — `help.mirror.cernet.edu.cn` does not resolve) is the CERNET 校园网联合镜像站 (MirrorZ). It is an **index/help aggregator, not a mirror itself**: it doesn't host packages, it points you at member mirrors (TUNA / USTC / NJU / SJTU / ...) and their per-project help pages. Never configure Nix to use `help.mirrors.cernet.edu.cn` or `mirrors.cernet.edu.cn` as a source.

## substituter 列表与单源

Single source of truth for the substituter list *and* the cachix key is the repo-root `meta.json` (flat fields: space-separated `substituters`, `nixCommunityCachixKey` — same pre-Nix constraint as `username`): `home/nix-cn.nix` consumes it via `fromJSON`/`splitString`, the three bootstrap scripts via the same sed pattern they use for `username`. `home/nix-cn.nix` remains the Nix-side module, imported by `modules/fix-network.nix` (NixOS daemon) and both `home/standalone-*.nix` entries. Current list: NJU → TUNA → USTC → SJTU → `cache.nixos.org` fallback (ordered by 2026-08 measured latency) **→ `nix-community.cachix.org` last**; the official cache is part of the shared string so bootstrap-written user-level configs match `nix-cn.nix` exactly (this fixed a pre-existing drift where bootstrap appended the official cache after cachix).

## rainbow-delimiters-nvim 事件（2026-09-24，复测 09-27）

The community cache is not a latency choice but a correctness one, added 2026-09-24: `vimPlugins.rainbow-delimiters-nvim` carries `meta.hydraPlatforms = [ ]` and its `fetchgit` source lives on gitlab.com — after a flake update rolled the plugin onto a derivation path no cache had built, neither the build nor the source was on `cache.nixos.org` or any domestic mirror (all 404, see VALIDATION.md 2026-09-24), so building `home/nixvim.nix` had to `git fetch https://gitlab.com/HiPhish/rainbow-delimiters.nvim` at build time — which fails outright on networks where gitlab.com is unreachable, cascading vimplugin → neovim → nixvim → `home-manager-path` → HM generation. Re-verified 2026-09-27: the plugin's nixpkgs license metadata at the locked revs is now Apache-2.0 (the earlier `meta.license = unfree` reading no longer holds; its source is publicly hosted on GitLab), and the exact locked plugin path substitutes from `cache.nixos.org` and NJU — the cachix entry is currently insurance rather than a hard requirement. Keep it anyway: `hydraPlatforms = [ ]` still stands, and after future `nix flake update`s the same combination (fresh derivation not yet on any cache + unreachable gitlab) can recur.

公钥归属：NixOS 侧在 `modules/fix-network.nix`；standalone 侧由 `bootstrap/*.sh` 写入 `/etc/nix/nix.custom.conf`，单用户安装写用户级 nix.conf；列表与公钥本体单源于仓库根 `meta.json`，Nix 模块与脚本同读一份，改动只改这一处。

## cachix 公钥的严格归属

The cachix key (`nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=`, signature-verified with `nix store verify` against the cache's narinfo; the older, still widely quoted `LwCD…` key is stale and reports the path as untrusted; the key value itself is single-sourced from `meta.json`'s `nixCommunityCachixKey`) belongs **only where it is honored**: `modules/fix-network.nix` (`nix.settings.trusted-public-keys`, merged with the default `cache.nixos.org-1` by the NixOS list merge), and the bootstrap scripts — daemon-side `nix.custom.conf` (multi-user) or user `nix.conf` (single-user). It must **not** go in `home/nix-cn.nix`: that would land in the standalone user `nix.conf`, where `trusted-public-keys` is a restricted setting for non-trusted users (`trusted-users = root`) and every daemon-touching command prints `ignoring the client-specified setting 'trusted-public-keys'`. Installer/daemon key lines use the `extra-trusted-public-keys` prefix so the built-in `cache.nixos.org-1` and any installer-written keys are appended to, never replaced.

## npm registry

npm/npx 的 registry 统一在 `home/common.nix` 配置：默认 `NPM_CONFIG_REGISTRY=https://registry.npmmirror.com`（npmmirror）；A 不可用时用 bash 别名 `npmr` 切到 NJU 南大源（`https://repo.nju.edu.cn/repository/npm/`）。USTC 的 npm 反向代理已于 2026-06-12 停服（请求 302 → npmmirror），不要添加。

## bootstrap 侧写入机制

Keep `bootstrap/linux.sh` and `bootstrap/darwin.sh` in sync: the list/key *values* all come from `meta.json` now, but the write mechanics must stay mirrored — on non-NixOS multi-user installs (macOS included) the same list must be written to `/etc/nix/nix.custom.conf` as `trusted-substituters`, the cachix key appended as `extra-trusted-public-keys`, and `/etc/nix/nix.conf` must include that file — otherwise Nix ignores the user-level substituters with a warning. Single-user Linux installs (`NIX_INSTALL_MODE=single`) have no daemon and write the same list plus `extra-trusted-public-keys` to the user-level `~/.config/nix/nix.conf` instead, where no trust grant is needed. `bootstrap/nixos.sh` uses the same list and key for its bootstrap-time `nix.custom.conf` and `NIX_CONFIG` (reading `meta.json` from its own checkout location — `SCRIPT_REPO` — because `CLONE_DIR` isn't cloned yet at its step 1). The skip checks in all bootstrap scripts key off `nix-community.cachix.org` (previously NJU) so pre-cachix installs are rewritten once rather than skipped — changing the cache list or key now means editing `meta.json` alone (all five consumers read it); the skip checks grep the *target* files and only need review if the marker cache changes again.

## 已死 / 重定向的源（考古）

- Binary caches only cover store paths. Flake inputs (`github:nixos/nixpkgs/...`, `home-manager`, ...) still fetch source from GitHub; the nixpkgs **git** mirrors at USTC/SJTU are dead (404 as of 2026-08) — don't point flake inputs at them.
- SJTU is the only listed mirror providing nix-darwin binary cache (needed for `standalone-darwin`); TUNA/USTC/BFSU don't.
- BFSU's `/nix-channels/store` is a 302 redirect to TUNA, not an independent source — don't add it.
