# Gitee → GitHub 同步

Gitee 是主仓库，GitHub Actions 在每小时第 17、47 分钟拉取所有分支和标签，
再推送到 `NoSeventh/nix-roam`。日常只需推送 Gitee；可在 GitHub Actions 的
`Sync from Gitee` 页面点击 `Run workflow` 手动同步。定时运行可能延迟。
拉取使用 Git 协议 v1，并在失败后间隔重试，最多尝试四次。

## push 前本地拦截（可选钩子）

GitHub 侧 `eval` workflow 在同步之后运行，属事后报警。仓库自带 pre-push 钩子
把 CI 第一层（五输出求值）前移到 push 时，一次性启用：

```bash
git config core.hooksPath .githooks
```

钩子即一条 `roam check nixos wsl x86_64-linux aarch64-linux aarch64-darwin`
（多目标求值，秒级；任一输出求值失败即拦下本次 push，全部跑完才退出）。
`core.hooksPath` 是本机配置，不随提交同步，每台推送机各自启用一次；
`git push --no-verify` 跳过一次。`.githooks/` 现仅含 pre-push（仓库原本不用
其它本地钩子）。注意：双推工作流文件变更（本文件所在目录的改动）也过同一
钩子——钩子只拦不改推送目标，双推流程不变。

Gitee 仓库必须保持公开。工作流使用 GitHub 自动提供的 `GITHUB_TOKEN`，
无需设置个人令牌或 SSH 密钥。同步只更新 Git 分支和标签，不包含 Issues、
Pull Requests、Release 附件或 Git LFS 对象。

同步不会强制覆盖分叉历史，也不会删除 GitHub 独有的分支或标签。
如果两边分叉、标签被改写或分支保护拒绝推送，整个原子推送失败，
请查看运行日志并处理差异后重试。

工作流文件需保留在 Gitee 的 `master` 分支。GitHub 自带令牌不能用于推送
工作流文件的变更；以后修改 `.github/workflows/` 时，使用本机凭据将同一提交
推送到 Gitee 和 GitHub。工作流自身变更推送到 GitHub 后会触发一次验证运行。

公开 GitHub 仓库连续 60 天没有活动时，定时工作流会自动停用，届时需到
Actions 页面重新启用。避免直接在 GitHub 上修改代码，以保持单向同步。
