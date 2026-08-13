# npm / npx 国内镜像源实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让三端（NixOS / standalone Linux / WSL / macOS）的 npm 与 npx 默认走 npmmirror 镜像源，并提供 NJU 南大源作为一条命令切换的兜底。

**Architecture:** 在 `home/common.nix`（三端共享）的 npm 段加 `NPM_CONFIG_REGISTRY` 环境变量作为默认源 A；在 bash `shellAliases` 加 `npmr` 别名携带 `--registry` 切到 NJU 源 B（npm 原生不支持多 registry 自动回退，故 B 为手动兜底）；`AGENTS.md` 补一条镜像说明。

**Tech Stack:** Nix flake / Home Manager。本仓库无测试框架（AGENTS.md），验证方式 = `nix-instantiate --parse` 语法检查 + `nix eval` 配置断言 + `nix build .#homeConfigurations.xuqihao.activationPackage` 干跑。

**环境注意事项（执行者必读）：**

- 沙箱限制：`nix eval` / `nix build` 需要写 `~/.cache/nix` 与 store（沙箱只读 → 报错），`git add` / `git commit` 需要写 `.git`（只读）。**遇到 Read-only file system / 权限错误时用 `require_escalated` 原样重跑该命令**，不要改用其他方式绕过。
- `nix eval` 输出用 `2>&1 | tail -1` 截取，避免长篇告警噪音。
- 只 `git add` 任务列出的文件；工作树其余部分保持不动。
- npm 环境变量只对新 shell 生效；`npmr` 是 bash 别名，同样需要新 shell。

---

## 文件结构

| 文件 | 职责 | 操作 |
|---|---|---|
| `home/common.nix` | 三端共享 CLI 核心；npm 段加默认 registry，bash aliases 加兜底别名 | 修改（Task 1 / Task 2） |
| `AGENTS.md` | 镜像配置文档，保持单一事实源说明同步 | 修改（Task 3） |

---

### Task 1: 默认源 A —— `NPM_CONFIG_REGISTRY` 指向 npmmirror

**Files:**
- Modify: `home/common.nix:82-85`（npm 段的 `home.sessionVariables`）

- [ ] **Step 1: 修改 `home/common.nix`**

把 npm 段（第 82-85 行）改成：

```nix
  # --- 6. npm ---
  home.sessionVariables = {
    NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";
    # 中国大陆加速：默认走 npmmirror（npm / npx 通用）。
    # 环境变量优先级高于项目级 .npmrc；个别项目要用自己的 registry 时：
    #   npm i --registry=<url>   或   unset NPM_CONFIG_REGISTRY
    NPM_CONFIG_REGISTRY = "https://registry.npmmirror.com";
  };
```

- [ ] **Step 2: 语法检查**

Run: `nix-instantiate --parse home/common.nix`
Expected: 无输出，退出码 0。

- [ ] **Step 3: 配置断言（eval）**

Run: `nix eval --json .#homeConfigurations.xuqihao.config.home.sessionVariables.NPM_CONFIG_REGISTRY 2>&1 | tail -1`
Expected: `"https://registry.npmmirror.com"`

若沙箱报 Read-only file system，用 `require_escalated` 重跑同一条命令。

- [ ] **Step 4: 提交**

```bash
git add home/common.nix
git commit -m "feat: use npmmirror as default npm registry"
```

---

### Task 2: 兜底源 B —— `npmr` 别名指向 NJU 南大源

**Files:**
- Modify: `home/common.nix:34-46`（`programs.bash.shellAliases`）

- [ ] **Step 1: 修改 `home/common.nix`**

在 `hms = "home-manager switch --flake .#xuqihao";` 之后插入：

```nix
      # npm 兜底源（npmmirror 不可用时）：npmr install <pkg>
      npmr = "npm --registry=https://repo.nju.edu.cn/repository/npm/";
```

- [ ] **Step 2: 语法检查**

Run: `nix-instantiate --parse home/common.nix`
Expected: 无输出，退出码 0。

- [ ] **Step 3: 配置断言（eval）**

Run: `nix eval --json .#homeConfigurations.xuqihao.config.programs.bash.shellAliases.npmr 2>&1 | tail -1`
Expected: `"npm --registry=https://repo.nju.edu.cn/repository/npm/"`

若沙箱报 Read-only file system，用 `require_escalated` 重跑同一条命令。

- [ ] **Step 4: 提交**

```bash
git add home/common.nix
git commit -m "feat: add npmr alias for NJU npm fallback mirror"
```

---

### Task 3: `AGENTS.md` 文档同步

**Files:**
- Modify: `AGENTS.md`（"China mirrors" 一节，第 115 行 "Single source of truth" 条目之后）

- [ ] **Step 1: 修改 `AGENTS.md`**

在 `home/nix-cn.nix` 的 "Single source of truth" 条目后追加一条：

```markdown
- npm/npx 的 registry 统一在 `home/common.nix` 配置：默认 `NPM_CONFIG_REGISTRY=https://registry.npmmirror.com`（npmmirror）；A 不可用时用 bash 别名 `npmr` 切到 NJU 南大源（`https://repo.nju.edu.cn/repository/npm/`）。USTC 的 npm 反向代理已于 2026-06-12 停服（请求 302 → npmmirror），不要添加。
```

- [ ] **Step 2: 确认文档落位**

Run: `rg -n "npmmirror|npmr" AGENTS.md`
Expected: 两条匹配（均为刚才插入的内容）。

- [ ] **Step 3: 提交**

```bash
git add AGENTS.md
git commit -m "docs: document npm registry mirror setup"
```

---

### Task 4: 端到端构建验证（干跑，不切换）

**Files:** 无（只验证）

- [ ] **Step 1: 构建 standalone HM activation package**

Run: `nix build .#homeConfigurations.xuqihao.activationPackage`
Expected: 构建成功，退出码 0。

若沙箱报 Read-only file system / store 写入错误，用 `require_escalated` 重跑。

- [ ] **Step 2: 记录验证结果**

把 Task 1 / Task 2 / Task 3 的 eval 与构建输出汇总给用户确认。

---

### Task 5: 激活后运行期验证（由用户执行）

**Files:** 无

> 激活命令因机器而异，不在此计划内自动执行：NixOS 用 `sudo nixos-rebuild switch`（`nrs`），非 NixOS 用 `home-manager switch --flake .#xuqihao`（`hms`）。激活后开新 shell 验证：

- [ ] **Step 1: 验证默认源 A**

Run: `npm config get registry`
Expected: `https://registry.npmmirror.com`

- [ ] **Step 2: 验证兜底别名 B**

Run: `npmr config get registry`
Expected: `https://repo.nju.edu.cn/repository/npm/`

两命令均不依赖网络；若输出与预期不符，检查是否开了新 shell（环境变量与别名只在登录/新 shell 生效）。
