# bootstrap/linux.sh 国内镜像授权实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `bootstrap/linux.sh` 中新增“配置国内镜像信任”步骤（幂等写入 `/etc/nix/nix.custom.conf` 的 `trusted-substituters`），让多用户 daemon 机器上用户级 TUNA/USTC 镜像真正生效。

**Architecture:** 在“安装 Nix”（现 1/5）之后插入新步骤 2/6；用 `sudo grep` 判断 TUNA 镜像 URL 是否已存在于 `/etc/nix/nix.custom.conf`，已存在则跳过，否则 `sudo mkdir -p /etc/nix` 后追加一行 `trusted-substituters`。镜像列表仍只由 `home/nix-cn.nix` 维护，bootstrap 只做“授权”。后续步骤（flakes / 备份 / home-manager / 激活）重新编号为 3/6–6/6。

**Tech Stack:** bash（`set -euo pipefail`，`log()`/`have()` 辅助函数）。本仓库无测试框架，验证 = `bash -n` 语法检查 + 步骤编号一致性检查 + diff 审阅。

---

## 文件结构

| 文件 | 职责 | 操作 |
|---|---|---|
| `bootstrap/linux.sh` | 全新 Linux/macOS 上的一键便携 Nix 安装 | 修改（插入步骤 + 重新编号） |

---

### Task 1: 修改 `bootstrap/linux.sh`

**Files:**
- Modify: `bootstrap/linux.sh`

- [ ] **Step 1: 插入新步骤 2/6**

在“1/5 安装 Nix”代码块结束之后（即 `# 2/5 永久开启 flakes` 注释块之前）插入以下内容：

```bash
# ---------------------------------------------------------------------------
# 2/6 配置国内镜像信任（多用户 daemon 下让用户级 substituters 生效）
#     幂等：nix.custom.conf 已含 TUNA 镜像则跳过，不重复叠加。
# ---------------------------------------------------------------------------
log "2/6 配置国内镜像信任"
NIX_CUSTOM_CONF="/etc/nix/nix.custom.conf"
TRUSTED_SUBSTITUTERS="https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://mirrors.ustc.edu.cn/nix-channels/store"
if [ -f "$NIX_CUSTOM_CONF" ] && sudo grep -q "mirrors.tuna.tsinghua.edu.cn/nix-channels/store" "$NIX_CUSTOM_CONF"; then
  echo "    已配置国内镜像信任，跳过"
else
  sudo mkdir -p /etc/nix
  printf 'trusted-substituters = %s\n' "$TRUSTED_SUBSTITUTERS" | sudo tee -a "$NIX_CUSTOM_CONF" > /dev/null
  echo "    已写入 $NIX_CUSTOM_CONF"
fi
```

- [ ] **Step 2: 重新编号后续步骤**

把后续所有 `N/M` 编号从 5 步改为 6 步（注释分隔行和 `log "..."` 字符串都要改）：

| 原 | 新 |
|---|---|
| `1/5 安装 Nix` | `1/6 安装 Nix` |
| `2/5 永久开启 flakes` | `3/6 永久开启 flakes` |
| `3/5 备份将被接管的家目录文件` | `4/6 备份将被接管的家目录文件` |
| `4/5 永久安装 home-manager` | `5/6 永久安装 home-manager` |
| `5/5 激活便携 CLI 环境` | `6/6 激活便携 CLI 环境` |

具体做法：把 `bootstrap/linux.sh` 中出现的 `1/5`、`2/5`、`3/5`、`4/5`、`5/5`（注释与 `log` 字符串内）分别替换为上表新值；不要改动脚本尾部 `cat <<EOF` 提示文案里的“以后更新配置”部分（与编号无关）。

- [ ] **Step 3: 语法检查**

Run: `bash -n bootstrap/linux.sh`

Expected: 无输出，退出码 0。

- [ ] **Step 4: 编号一致性检查**

Run: `rg -n 'log "[0-9]/[0-9]+ ' bootstrap/linux.sh`

Expected: 恰好 6 行，依次为 `1/6`、`2/6`、`3/6`、`4/6`、`5/6`、`6/6`。

- [ ] **Step 5: 提交**

```bash
git add bootstrap/linux.sh
git commit -m "feat: add trusted-substituters step to bootstrap/linux.sh"
```

---

### Task 2: 最终验证

**Files:** 无（只读检查）

- [ ] **Step 1: diff 审阅**

Run: `git show --stat HEAD && git show HEAD -- bootstrap/linux.sh`

Expected: 本次提交只改动 `bootstrap/linux.sh`；diff 显示新增步骤 2/6 位于安装 Nix 之后、flakes 之前；`TRUSTED_SUBSTITUTERS` 的两个 URL 与 `home/nix-cn.nix` 中的镜像一致；后续步骤编号为 3/6–6/6。

- [ ] **Step 2: 工作树确认**

Run: `git status --short`

Expected: 干净。

- [ ] **Step 3: 汇总**

确认 spec §8 的要求逐条落地：幂等、`sudo mkdir -p /etc/nix` 兜底、平台无关（无 Linux 专属命令）、不重复写 `substituters`。

> 注：`sudo` 写 `/etc/nix` 的真实生效路径只能在真实机器上运行 bootstrap（或单独执行该片段）验证；本计划以语法 + 编号 + diff 审阅作为仓库内验证。

---

## 与 spec 的对应关系

- spec §8（bootstrap 集成：国内镜像授权）→ Task 1、Task 2
