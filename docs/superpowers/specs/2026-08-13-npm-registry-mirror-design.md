# npm / npx 国内镜像源配置设计：`home/common.nix` 加默认源 + 兜底别名

- 日期：2026-08-13
- 状态：已批准（待实现）
- 作者：xuqihao

## 1. 目标

让本仓库所有安装路径（NixOS / standalone Linux / WSL / macOS）的 **npm 与 npx** 默认走国内镜像源，加快在中国大陆的下载速度：

- **默认源（A）**：npmmirror（原淘宝）`https://registry.npmmirror.com`。
- **兜底源（B）**：NJU 南大源 `https://repo.nju.edu.cn/repository/npm/`，A 不可用时一条命令切换。
- **三端共享**：配置放在 `home/common.nix`（NixOS 与 standalone 两个入口都已 import），不新增文件。

## 2. 非目标

- **不做** npm 多 registry 自动回退——npm 原生不支持多 registry failover，`.npmrc` / 环境变量只能设一个 registry。
- **不托管 `~/.npmrc`**——HM `home.file` 生成的是只读软链，手动 `npm config set` 会失败或被重建覆盖，兜底切换反而变麻烦。
- **不改** `bootstrap/linux.sh`——这是 HM 用户级配置，非 NixOS 安装走 standalone 入口即可生效。
- **不处理 `sudo npm`**——NixOS 上 nodejs 在 `environment.systemPackages`，root 的 npm 读的是 `/root` 配置；本次只覆盖普通用户。
- **不动** Node.js 安装本身（`pkgs-stable.nodejs` 已在 `packages/cli-dev.nix` 三端共享）。
- **不用** Home Manager 的 `programs.npm` 模块——选项名（`npmrc` / `settings` / `registry`）未在 pinned 的 HM master 版本验证，一行配置不值得引入该不确定性。

## 3. 现状与结论

现状：

- `home/common.nix` 的 npm 段已有 `NPM_CONFIG_PREFIX`、`sessionPath` 含 `.npm-global/bin`，但没有任何 registry 配置。
- nodejs 经 `packages/cli-dev.nix` 进入三处安装点（`modules/programs.nix` / `home/standalone-linux.nix` / `home/standalone-darwin.nix`），所以 `home/common.nix` 是覆盖三端的唯一正确落点。
- npm 与 npx 共用同一套 npm 配置；`NPM_CONFIG_REGISTRY` 环境变量对两者同时生效。

配置优先级（npm 官方文档）：命令行 `--registry` 参数 > 环境变量 > 项目级 `.npmrc` > 用户级 `.npmrc` > 全局 `.npmrc` > 内置默认。

镜像源现状（2026-08 核实）：

- **USTC npm 镜像已停服**：`mirrors.ustc.edu.cn/help/npm.html` 明确说明反向代理服务已于 2026-06-12 停止，所有请求 302 至 npmmirror——不能当兜底（等于还是 A），与 AGENTS.md 中 "BFSU 302 到 TUNA 不添加" 同理。
- **NJU 南大源可用**：`https://repo.nju.edu.cn/repository/npm/`，官方文档（doc.nju.edu.cn）仍在维护，腾讯云 + 官方源混合代理；也与 nix-cn 镜像列表中 NJU 排第一的风格一致。
- npmmirror 为国内最主流 npm 镜像，CDN 覆盖广，作为默认源。

## 4. 设计

### 4.1 `home/common.nix` — 默认源（A）

在现有 npm 段的 `home.sessionVariables` 中追加一行，与 `NPM_CONFIG_PREFIX` 并列：

```nix
home.sessionVariables = {
  NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";
  NPM_CONFIG_REGISTRY = "https://registry.npmmirror.com";
};
```

注释说明：环境变量优先级高于项目级 `.npmrc`；个别项目需要自己的 registry 时用 `npm i --registry=<url>` 或临时 `unset NPM_CONFIG_REGISTRY`。

### 4.2 `home/common.nix` — 兜底别名（B）

在现有 bash `shellAliases` 中加：

```nix
npmr = "npm --registry=https://repo.nju.edu.cn/repository/npm/";
```

用法：`npmr install <pkg>`；A 恢复后再用回普通 `npm`，不需要改动任何配置文件。

### 4.3 `AGENTS.md` — 文档同步

在 "China mirrors" 一节补一句：npm/npx 默认 npmmirror，兜底用 `npmr` 别名（NJU 源）；USTC npm 镜像已停服，勿添加。

## 5. 验证

仓库无测试框架（AGENTS.md），按惯例构建验证：

1. `nix build .#homeConfigurations.xuqihao.activationPackage`（standalone 干跑）或 NixOS 侧 `nix build .#nixosConfigurations.nixos.config.system.build.toplevel`。
2. 新 shell 中：
   - `npm config get registry` → `https://registry.npmmirror.com`（A 生效）。
   - `npmr config get registry` → `https://repo.nju.edu.cn/repository/npm/`（B 可切换）。
   - 两命令均不依赖网络，仅验证配置值。

## 6. 影响面

- `home/common.nix`：+1 环境变量、+1 别名、少量注释。
- `AGENTS.md`：+1 行说明。
- 无新增文件、无 flake 变更、无包列表变更、不影响既有 `.npmrc`（本机如已有手工配置，环境变量优先级更高，行为符合预期）。
