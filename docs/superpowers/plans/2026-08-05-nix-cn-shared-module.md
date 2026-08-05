# Nix-CN 共享模块实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Nix 侧中国大陆网络适配从"仅 NixOS 生效"扩展到 NixOS / standalone Linux / WSL / macOS 全部安装路径，并用 `home/nix-cn.nix` 单一共享模块消除重复。

**Architecture:** 新增一个只声明 `nix.settings` 的小模块 `home/nix-cn.nix`（substituters：清华/中科大 + cache.nixos.org，connect-timeout，fallback），被 NixOS 侧（`modules/fix-network.nix`）与两个 standalone 入口（`home/standalone-linux.nix`、`home/standalone-darwin.nix`）共同 `imports`。daemon 级设置（`auto-optimise-store`、`download-buffer-size`）留在 `fix-network.nix`，避免在非 trusted 用户的多用户 daemon 机器上产生受限设置警告。

**Tech Stack:** Nix flake / NixOS module system / Home Manager module system。本仓库无测试框架（见 AGENTS.md），验证方式 = `nix eval` 断言 + `nix-instantiate --parse` 解析检查。

**环境注意事项（执行者必读）：**

- 沙箱限制：`nix eval` 需要写 `~/.cache/nix`（沙箱只读 → `Read-only file system`），`git add` / `git commit` 需要写 `.git/index.lock`（同样只读）。**遇到上述错误时用 `require_escalated` 原样重跑该命令**，不要改用其他方式绕过。
- 带连字符的设置名在 `nix eval` 路径里必须用引号，例如 `."connect-timeout"`。
- 工作树除本仓库文档外应保持干净；提交时只 `git add` 任务列出的文件。

---

## 文件结构

| 文件 | 职责 | 操作 |
|---|---|---|
| `home/nix-cn.nix` | 三端共享的 Nix 网络适配（唯一事实源） | 新增 |
| `modules/fix-network.nix` | NixOS daemon 级适配（保留 daemon-only 设置，imports 共享模块） | 修改 |
| `home/standalone-linux.nix` | standalone Linux/WSL 入口（imports 共享模块） | 修改 |
| `home/standalone-darwin.nix` | macOS 入口（imports 共享模块） | 修改 |

---

### Task 1: 新增共享模块 `home/nix-cn.nix`

**Files:**
- Create: `home/nix-cn.nix`

- [ ] **Step 1: 创建文件**

完整内容（与 spec §4.1 一致）：

```nix
# 中国大陆网络适配（Nix 侧共享配置，单一事实源）
# 被 modules/fix-network.nix（NixOS daemon）与 home/standalone-{linux,darwin}.nix（用户级）共同 import。
# 只放三端都安全生效的设置；daemon 级设置（download-buffer-size / auto-optimise-store）留在 fix-network.nix。
{ lib, ... }:

{
  nix.settings = {
    # 优先使用国内镜像站
    substituters = lib.mkForce [
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://cache.nixos.org/"
    ];

    connect-timeout = 5;
    fallback = true;
  };
}
```

- [ ] **Step 2: 解析检查**

Run: `nix-instantiate --parse home/nix-cn.nix > /dev/null && echo PARSE_OK`

Expected: `PARSE_OK`，无语法错误。（`nix-instantiate --parse` 只做语法解析，不需要网络或 daemon。）

- [ ] **Step 3: 提交**

```bash
git add home/nix-cn.nix
git commit -m "feat: add shared nix-cn network settings module"
```

---

### Task 2: 接入 `modules/fix-network.nix`（NixOS 行为不变）

**Files:**
- Modify: `modules/fix-network.nix`

- [ ] **Step 1: 记录回归基线**

Run: `nix eval --json .#nixosConfigurations.nixos.config.nix.settings.substituters`

Expected（现状，后续必须原样保持）:
`["https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store","https://mirrors.ustc.edu.cn/nix-channels/store","https://cache.nixos.org/"]`

- [ ] **Step 2: 修改文件**

把 `modules/fix-network.nix` 的完整内容改为：

```nix
{ ... }:

{
  imports = [ ../home/nix-cn.nix ];

  nix.settings = {
    # 增大下载缓存，防止大文件下载中断 (500MB)
    download-buffer-size = 524288000;

    # 自动优化存储，节省空间
    auto-optimise-store = true;
  };

#   nix.extraOptions = ''
#     !include /etc/nix/github-access-tokens
#   '';

  environment.variables = {
    NIXPKGS_ALLOW_UNFREE = "1";
#    GOPROXY = "https://goproxy.cn,direct";
  };

#  systemd.services.nix-daemon.environment = {
#    GOPROXY = "https://goproxy.cn,direct";
#  };
}
```

要点：新增 `imports = [ ../home/nix-cn.nix ];`；删除原 `nix.settings` 里的 `substituters`、`connect-timeout`、`fallback`（改由共享模块提供）；`download-buffer-size`、`auto-optimise-store`、`NIXPKGS_ALLOW_UNFREE` 与被注释块全部保留；模块不再使用 `config/pkgs/lib`，签名简化为 `{ ... }:`（符合 AGENTS.md 风格）。

- [ ] **Step 3: 验证 NixOS 侧值与基线一致**

Run 以下三条，全部通过：

```bash
nix eval --json .#nixosConfigurations.nixos.config.nix.settings.substituters
nix eval --json .#nixosConfigurations.nixos.config.nix.settings."connect-timeout"
nix eval --json .#nixosConfigurations.nixos.config.nix.settings."auto-optimise-store"
```

Expected:
- 第一条：`["https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store","https://mirrors.ustc.edu.cn/nix-channels/store","https://cache.nixos.org/"]`
- 第二条：`5`
- 第三条：`true`

（若遇到 `Read-only file system`，用 `require_escalated` 重跑。）

- [ ] **Step 4: 提交**

```bash
git add modules/fix-network.nix
git commit -m "refactor: share nix-cn settings via home/nix-cn.nix on NixOS"
```

---

### Task 3: 接入 `home/standalone-linux.nix`

**Files:**
- Modify: `home/standalone-linux.nix`

- [ ] **Step 1: 确认当前为空（红）**

Run: `nix eval --json .#homeConfigurations.xuqihao.config.nix.settings`

Expected: `{}`（standalone 目前没有任何 `nix.settings`，证明缺失）

- [ ] **Step 2: 修改文件**

把 `home/standalone-linux.nix` 的 imports 块改为：

```nix
  imports = [
    ./common.nix
    ./nix-cn.nix
  ];
```

- [ ] **Step 3: 验证共享配置生效（绿）**

Run:

```bash
nix eval --json .#homeConfigurations.xuqihao.config.nix.settings.substituters
nix eval --json .#homeConfigurations.xuqihao.config.nix.settings."connect-timeout"
nix eval --json .#homeConfigurations.xuqihao.config.nix.settings.fallback
```

Expected:
- `["https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store","https://mirrors.ustc.edu.cn/nix-channels/store","https://cache.nixos.org/"]`
- `5`
- `true`

再确认 daemon 级设置没有混进用户配置：

Run: `nix eval --json .#homeConfigurations.xuqihao.config.nix.settings."auto-optimise-store"`

Expected: `error: attribute 'auto-optimise-store' missing`（证明共享模块只带三端安全的设置）

- [ ] **Step 4: 提交**

```bash
git add home/standalone-linux.nix
git commit -m "feat: apply nix-cn mirror settings to standalone linux/WSL"
```

---

### Task 4: 接入 `home/standalone-darwin.nix`

**Files:**
- Modify: `home/standalone-darwin.nix`

- [ ] **Step 1: 确认当前为空（红）**

Run: `nix eval --json .#homeConfigurations.xuqihao-darwin.config.nix.settings`

Expected: `{}`

- [ ] **Step 2: 修改文件**

把 `home/standalone-darwin.nix` 的 imports 块改为：

```nix
  imports = [
    ./common.nix
    ./nix-cn.nix
  ];
```

- [ ] **Step 3: 验证共享配置生效（绿）**

Run:

```bash
nix eval --json .#homeConfigurations.xuqihao-darwin.config.nix.settings.substituters
nix eval --json .#homeConfigurations.xuqihao-darwin.config.nix.settings."connect-timeout"
nix eval --json .#homeConfigurations.xuqihao-darwin.config.nix.settings.fallback
```

Expected: 与 Task 3 Step 3 相同的三个输出（darwin 目标可在 x86_64-linux 上求值，已验证）。

- [ ] **Step 4: 提交**

```bash
git add home/standalone-darwin.nix
git commit -m "feat: apply nix-cn mirror settings to standalone macOS"
```

---

### Task 5: 最终集成验证

**Files:** 无（只读检查）

- [ ] **Step 1: 全量断言**

按顺序运行并核对输出：

```bash
# NixOS：基线值不变
nix eval --json .#nixosConfigurations.nixos.config.nix.settings.substituters
nix eval --json .#nixosConfigurations.nixos.config.nix.settings."auto-optimise-store"
nix eval --json .#nixosConfigurations.nixos.config.nix.settings."download-buffer-size"
# standalone linux：三个键
nix eval --json .#homeConfigurations.xuqihao.config.nix.settings.substituters
nix eval --json .#homeConfigurations.xuqihao.config.nix.settings."connect-timeout"
nix eval --json .#homeConfigurations.xuqihao.config.nix.settings.fallback
# standalone darwin：三个键
nix eval --json .#homeConfigurations.xuqihao-darwin.config.nix.settings.substituters
nix eval --json .#homeConfigurations.xuqihao-darwin.config.nix.settings."connect-timeout"
nix eval --json .#homeConfigurations.xuqihao-darwin.config.nix.settings.fallback
```

Expected:
- NixOS `substituters`：三个镜像列表；`auto-optimise-store`：`true`；`download-buffer-size`：`524288000`
- 两个 standalone 的 `substituters`：均为三个镜像列表；`connect-timeout`：`5`；`fallback`：`true`

- [ ] **Step 2: 工作树状态确认**

Run: `git status --short`

Expected: 干净（无未提交改动；如有其他无关改动，不要动它们，在最终报告里说明）。

- [ ] **Step 3: 汇总**

核对 spec 的生效矩阵与本计划 Task 2-4 的验证结果一一对应；无遗留 TODO。

---

## 与 spec 的对应关系

- spec §4.1（新增 `home/nix-cn.nix`）→ Task 1
- spec §4.2（改动 `modules/fix-network.nix`）→ Task 2
- spec §4.3（改动两个 standalone 入口）→ Task 3、Task 4
- spec §6（验证）→ Task 2-5
