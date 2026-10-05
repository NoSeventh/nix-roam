# 验证记录（Validation boundaries）

按日期记录每次改动实际验证到的边界（新 → 旧）。**状态只反映记录当时**，不代表当前提交已重新构建；具体验证环境（发行版 / 主机）以各条为准。

判断标准与常用手法：

- 对 Nix 改动：解析编辑过的文件 → 求值受影响的选项 / 派生 → 构建对应目标。不把「求值通过」当「构建通过」，不把「构建通过」当「激活通过」，也不把当前主机上找到的命令当作另一目标包内容的证据。
- 「纯重构」用五输出 drvPath 前后对比验证（干净树 vs 干净树）：`nix eval --raw .#<target>.drvPath`。注意 HM 侧 `programs.*` 子选项「显式设置为空值」与「未设置」可能生成不同文本（曾见于 `programs.bash.initExtra`：空串会多出一个换行），布尔注入必须用属性集级 `lib.optionalAttrs` 而非字符串级 `lib.optionalString`。
- 测试断言不得隐含宿主假设：凡被测路径消费宿主探测（`is_nixos` / `uname` 等），桩内一律钉死其返回值——否则用例语义随运行宿主漂移（2026-09-28 gc 用例在真 NixOS 上假失败一次后立此规矩，b9c3cea；且新脚本测试应在第二个宿主上跑过一遍才算数）。
- 对纯文档改动：检查源一致性、本地链接、被删路径的引用与 `git diff --check`，无需重建或激活。

## 2026-10-05 单用户安装器先行喂镜像（bootstrap/linux.sh + docs/bootstrap.md；Fedora 44 / WSL2 standalone，本机）

背景：Gentoo WSL 实机跑到 `installing 'nix-2.35.2' → building '…-user-environment.drv'` 长时间不动。该步是官方安装器收尾（本地组装 `~/.nix-profile`，本应秒级），卡点是它先查 substituter——此刻镜像还没写入 nix.conf（原设计步骤 2 才写），安装器内部 nix-env 只有默认 `cache.nixos.org`，而该机到 nixos.org 系为极慢直连（25MB 走 11m44s ≈ 43KB/s），无 connect-timeout 封顶时内核级 TCP 超时是分钟级（疑似叠加 IPv6 黑洞）。

改动：①镜像元数据（`TRUSTED_SUBSTITUTERS` / `CACHIX_PUBLIC_KEY` 的 meta.json 解析 + fail-loud）从步骤 2 前移为新 0.9 节，步骤 2 沿用同源变量（删重复解析）。②步骤 1 single 分支在调官方安装器前 `export NIX_CONFIG`（镜像列表 + cachix 公钥 + `connect-timeout = 5`）——安装器内部 nix-env 即走 NJU 等国内镜像查询，慢路连接等待 5 秒封顶；步骤 2 的会话级 NIX_CONFIG 同步补 `connect-timeout = 5`（此前只在 nix-cn.nix 与 daemon 侧有此约定，bootstrap 会话期是缺口）。③docs/bootstrap.md 两模式段落补记（含实测数据与日期）。

验证（本机 Fedora 44 / WSL2 standalone x86_64，用户 xuqihao）：`bash -n` 过；shellcheck 0.11.0 零告警；run-all 173/173（bootstrap-helpers 的 sed 提取不涉改动区域，12/12 不变）；`git diff --check` 干净。NIX_CONFIG 为环境变量注入，不落盘任何 nix.conf，无输出 drvPath 影响（未改 .nix）。

未验证：Gentoo WSL 实机的卡点复测——当前那次运行若自行放行（查询超时后落本地构建）即与本改动无关；若 Ctrl-C 后带同款 NIX_CONFIG 手工重跑成功，可作本改动的等效实证。安装器对 NIX_CONFIG 的继承按 nix 文档语义（所有 nix 命令读该环境变量）推定，未在真机上单独验证。

## 2026-10-05 bootstrap 单用户安装的 su 提权前端（bootstrap/linux.sh + tests/bootstrap-helpers.sh〔新〕+ tests/run-all.sh + README/AGENTS/docs·bootstrap + flake.nix 注释；Fedora 44 / WSL2 standalone，本机）

背景：在 Gentoo WSL 上以 `bash <(curl …)` 引导，登录用户与 meta.json 一致但机器没装 sudo——模式判定落入 single，步骤 1 因「/nix 需一次性 root 创建且无 sudo」fail-loud 中止并提示找管理员；而 WSL/普通机上用户自己经 root 密码走 `su` 即可完成这唯一一次提权，不必管理员介入。

改动：①linux.sh 新增提权前端 `run_as_root`（have sudo → sudo；无 sudo 且 stdin 是终端 → `su_root`；皆不可用 → 非零返回，fail-loud 留给调用方）与 `su_root`（`su -c` 只收一个命令串，参数经 `printf %q` 逐个消毒拼接；对普通词只产空格/& 反斜杠转义，POSIX sh 兼容，本路径不触发 `$'…'` 形式）。②步骤 1 single 分支重写：`/nix` 缺失 → `run_as_root sh -c 'mkdir -m 0755 /nix && chown <user> /nix'`（有 sudo 的机器结果不变——原先等价操作交给官方安装器内部 sudo；无 sudo 机器交互输 root 密码完成）；`/nix` 存在但不可写 → 同一前端尝试 chown 后复检；两者皆败的手动命令文案补 WSL `wsl -d <发行版> -u root` 进入方式。su 分支要求 `[ -t 0 ]`：`bash <(curl …)` 保留终端 stdin（README 交互性主张），`curl | bash` 无从输密码、直接落手动命令而非挂起。③0.8 模式日志补 su 可用性。④新测试 `tests/bootstrap-helpers.sh`（sed 提取 `run_as_root`/`su_root` 顶格多行函数体加载——linux.sh 不可整体 source，仓库定位段即开始执行；`have` 单行定义提不出来，测试内等价重定义、分派用例按需覆盖）12 例：sudo/su/皆无三分派、sudo 与 su 的 rc 透传、非终端 stdin 拒走 su（`< /dev/null` 钉死宿主 tty 状态——本条即「断言不得隐含宿主假设」的直接应用）、`su -c` 单串经 shell 重解析还原 argv（空格/& 元字符往返）。两个沙箱发现入注：stub 以 `$BASH` 为 shebang（nix build 沙箱无 `/usr/bin/env`，roam-functions 假 nix 同款手法）；新测试文件必须先 `git add` 才进 flake 源副本，否则沙箱内 run-all 找不到它而本地能跑（flake git-tree 过滤只认索引）。⑤run-all 汇总接入（161→173）、flake.nix scriptChecks 注释、AGENTS（单测手段补 sed 提取约束：两函数保持顶格多行）、README（单用户 `/nix` 一句 + `bash <(...)` 交互性主张补 su 依赖）、docs/bootstrap.md 同步。

验证（本机 Fedora 44 / WSL2 standalone x86_64，用户 xuqihao）：`bash -n` 三脚本过；shellcheck 0.11.0 零告警（`nix shell nixpkgs#shellcheck` 直跑三个改动脚本）；run-all 173/173（roam-functions 104 + prepush-gate 24 + 补全 22 + 脚手架 6 + repo-references 5 + bootstrap-helpers 12）；`nix build` 直建 `checks.x86_64-linux.shellcheck-scripts` 与 `checks.x86_64-linux.roam-unit-tests` rc=0（沙箱内两关卡，后者含新套件与 $BASH stub）；`git diff --check` 干净；**四输出 drvPath 提交前后逐一相同**（干净树对干净树——flake.nix 仅注释变化的「注释级纯重构」主张再实证；初次对比基于 99d4da6，当时桌面两侧同因尚未放行的 electron-41.10.7 拒评不可比〔该断点随后由 ac987f0 解决〕，rebase 到 ac987f0 后复核四输出仍逐一相同）。

未验证 / 发现：①Gentoo WSL 实机重跑——改动即由该场景触发，su 交互路径在真终端的密码提示、建好 `/nix` 后官方安装器 `--no-daemon` 全程未实测；预期直接重跑 `bash ~/nix-roam/bootstrap/bootstrap.sh` 即可走通（或 curl 一键，复用已有克隆）。②tty+su 正路径无合成端到端（单测以 su_root 直测拼串 + 非终端负路径夹逼覆盖；伪终端方案不引入）。③aarch64 两 check 本机直建被拒（x86_64 无 ARM，既有边界，CI 覆盖）。④本批期间本地曾并行做出一份 electron-41.10.7 允许项修复（41.9.1 两存的劣化版，11266ef），push 时撞上远端更完整的 ac987f0（stable 实例替换 + nixos-base 条目求值复核 + flake check/构建验证），rebase 时丢弃该提交，electron 问题以 ac987f0 为准。
## 2026-10-02 insecure 清单随 2f90778 flake 更新补齐：electron-41.10.7（flake.nix + profiles/nixos-base.nix 注释 + AGENTS，AlmaLinux 9.8 / WSL2 standalone，本机）

背景：上一条 VALIDATION 发现的既有断点——2f90778 update flake 后桌面 toplevel 求值拒评 electron-41.10.7（`nix flake check` 与桌面输出全挂）。用户批准按 AGENTS「Handling EOL / insecure packages」流程放行。

改动与过程：①实例归属探针——stable（rev 78e9c78）`electron_41` = 41.10.7、unstable（b4fd65b）`electron_41` = 41.10.6：拒评的 41.10.7 只可能来自 pkgsFor 管辖的 **stable 实例**（桌面闭包经 pkgs-stable 引用 electron_41，与 2026-09-26 引入 41.9.1 同一消费者）→ `flake.nix` 共享清单 electron-41.9.1 **替换**为 electron-41.10.7（旧版本随 stable 前移已无引用者，按 2026-09-17 先例替换不累积）。②nixos-base 侧清理尝试被求值推翻：依据顶点探针（unstable `electron`=43.6.0 / `electron_41`=41.10.6 / `pnpm`=12.3.4）判定 electron-40.10.5、pnpm-10.29.2 已死并移除，桌面求值相继拒评两者（unstable `electron_40` 仍是 40.10.5；GNOME 链仍钉 pnpm 10.29.2），逐条恢复——**顶点属性探针覆盖不了版本化/被钉住的引用面，条目存亡以受影响输出求值为准**（教训已记入两处注释与 AGENTS）。③flake bump 会串行暴露多个拒评（Nix 一次只报一个：先 stable electron，放行后才轮到 unstable electron/pnpm），修到目标通过为止。nixos-base 最终清单与改动前一致，仅注释重写。

验证（本机 AlmaLinux 9.8 / WSL2 standalone x86_64，用户 xuqihao）：五输出 drvPath 求值——桌面 `dz5jzkfp…-nixos-system-nixos-26.11.20260929.b4fd65b.drv`（修前拒评→修后通过）；WSL `nb79nvaz…` 与三个 standalone（`6azf98p…` / `qwais8b8…` / `k0adp9k…`）与改动前基线**逐一相同**（allow-only 语义；WSL 在 nixos-base 清单复原后二次核对仍同路径）；`nix flake check` rc=0（桌面求值解锁 + 当前系统两 check 重建通过；plain flake check 只构建当前系统的 check、aarch64 为求值覆盖，与 CI 同款行为）；`nix build --no-link .#homeConfigurations.x86_64-linux.activationPackage` rc=0；`git diff --check` 干净。

未验证：桌面 toplevel 仅求值未构建未激活（闭包过大，仓库惯例 eval-only——真实 nixos 主机上下一次 `roam switch` 才算激活验证）；aarch64 两 check 依旧仅求值覆盖（本机无 ARM，`--all-systems` 未跑）。

## 2026-10-02 roam flake 子命令：查看 flake.lock 锁定版本（packages/roam.sh + roam-completion + tests/×2 + README/AGENTS/docs×2，AlmaLinux 9.8 / WSL2 standalone，本机）

背景：roam 缺一个「现在锁的是哪些版本」的只读速览——`nix flake metadata` 要走求值且慢；`choose_inputs` 的输入表只在 update 交互里可见，且缺 jq 时降级。要求：快（不求值不触网）、随处可用（不依赖 jq）、维持 macOS Bash 3.2 兼容与「只用 bash 内建 + sed/grep」的既有约束。

改动：①`read_flake_lock`——纯 bash 行循环解析 flake.lock，只锚定 Nix 生成格式的缩进层级（节点名 4 空格 / locked·original·inputs 块 6 / 字段 8），不依赖键序与排序；root 直接输入经 `root.inputs` 解析为「声明名→锁定节点名」（`home-manager` 按声明名显示，实际节点是 `home-manager_2`）；follows 数组元素（10 空格缩进、无 `"key":` 结构）正则天然不中。②`lock_date`——epoch→UTC 日期，GNU `date -d @` / BSD `date -r` 双语法回落（doctor 回避日期运算是因为那只做字符串比较；这里是数值时间戳转换，双语法回落正是为此；都失败打 `-` 不算错）。③`cmd_flake`：缺省列 root 六输入（名称 / 7 位短 rev / 日期 / 声明 ref / owner-repo），`-a|--all` 追加传递输入表（排除 root 已引用节点，节点名带版本后缀）；root 输入解析为空即中止（fail-loud）——lock 版本换代重排缩进时报错而非打印空表。④补全一级清单 + `flake` 旗标；测试 roam-functions 75→104（解析器 fixture 全字段 / 真实 lock 结构断言〔六 root 输入、home-manager 指向后缀节点、rev 40 位 hex、nixpkgs_2 在表〕/ 空 lock 拒绝、lock_date 三例、cmd_flake 表内容空白归一比对 + 真实表成员 + 未知选项与位置参数拒绝）、补全 19→22；roam.sh 头注 / usage、README、AGENTS×2、docs/roam.md（速查条目 + 打包段补全清单）同步。

验证（本机 AlmaLinux 9.8 / WSL2 standalone x86_64，用户 xuqihao）：`bash -n` 全过；shellcheck 0.11.0 零告警（`nix shell nixpkgs#shellcheck` 直跑四个改动脚本）；run-all 161/161（roam-functions 104 + prepush-gate 24 + 补全 22 + 脚手架 6 + repo-references 5）；实机 `bash packages/roam.sh flake` / `flake --all` 输出核对（root 六输入齐全、home-manager 按声明名显示、hermes-agent 无声明 ref 显 `-`、传递表含 nixvim 自带 nixpkgs_2）；`nix build` 直建 `checks.x86_64-linux.shellcheck-scripts` + `checks.x86_64-linux.roam-unit-tests` rc=0（沙箱内两关卡）；`nix build --no-link .#homeConfigurations.x86_64-linux.activationPackage` rc=0（roam.sh 过 writeShellApplication 的 bash -n + shellcheck 门）；`git diff --check` 干净。

未验证 / 发现：①`nix flake check` 整体 rc=1——**既有问题，与本批无关**：stash 对照下干净 HEAD 同样在 `.#nixosConfigurations.nixos…toplevel` 求值处拒绝 electron-41.10.7（2f90778 update flake 后 nixpkgs unstable 的 electron 前移，允许清单未跟：共享侧 flake.nix 放行 electron-41.9.1，NixOS unstable 侧在 profiles/nixos-base.nix）；是否放行新版本属 insecure 审批，未擅自处理，留待决定；故第三层以上述直建两 check 替代整体 check。②aarch64 两 check 本机直建被拒（x86_64 无 ARM/模拟执行——既有边界，CI 覆盖）。③macOS Bash 3.2 实机未跑（`[[ =~ ]]` 区间量词 / `${var:0:7}` / 数组 `+=()` 均 3.1+ 原语，按惯例待第二宿主实证）。④已安装的 `bin/roam` 是旧世代，实机验证走 `bash packages/roam.sh flake` 调试路径；`roam switch` 后才进入正式入口。

## 2026-09-29 门控黑名单反转 + SIGPIPE/空行修正 + 清单静态审计（.githooks/pre-push + tests/prepush-gate.sh + AGENTS/docs·roam + flake.nix 注释，Fedora 44 / WSL2 standalone，本机）

背景（对上条门控的复评发现三点）：①`EVAL_INPUT_RE` 白名单形式与「宁多跑勿漏跑」教义相悖——漏列=误放行，恰是禁止的方向；②`printf | grep -q` 管道在 `set -o pipefail` 下有 SIGPIPE→141→判假的潜伏路径（触发条件苛刻但同属漏放行方向）；③清单只靠头注释提醒人工扩列，是全仓唯一无守卫的不变量（hostnameGuard 已立「约定→断言」先例）。另 `tests/fixtures/flake.lock` 在白名单下被 `(^|/)flake\.lock$` 过度命中（多跑方向无害，属精度损失）。

改动：①清单反转为黑名单 `EVAL_SKIP_RE`——docs/tests/bootstrap/.github/.githooks 五目录与根 README/AGENTS/LICENSE/.gitignore 为已知非输入，**清单外一律视为求值输入**：未知路径（近失名、新增根文件、目录导入内非 .nix 文件——`./hosts/<h>/` 整目录进 store 的潜伏缺口由此自动覆盖）全部保守拦下；漏扩清单的代价降为多跑一次（安全方向）。②判定改 here-string `grep -qEv <<<"$diff_out"`（无管道，SIGPIPE 面归零）+ 空差异显式 `[ -n ]` 前置——here-string 对空串产生一个空行，`-v` 会把空行当「未命中清单」误判为输入（实现时预判，「空差异放行」既有用例即其覆盖）。③prepush-gate 18→24 例：近失名语义反转（mypackages/x、dotfiles-extra/y、notes.flake.lock.bak 由放行改拦下）、已知非输入全集放行（含 fixtures/flake.lock 精度提升、根四文件、.github）、审计三断言（`EVAL_SKIP_RE` 在位防改名脱钩；全仓 .nix 相对路径引用清单目录 ==1——钉 flake.nix `${./tests}` 的 checks 专用引用，钉数前先独立 grep 确认真值；清单五目录内 .nix ==0）。④AGENTS CI 段、docs/roam.md check 条目、flake.nix scriptChecks 注释同步（flake.nix 仅注释变化）。

验证（本机 Fedora 44 / WSL2 standalone x86_64，用户 xuqihao）：`bash -n` / shellcheck 零告警（改动两文件）；run-all 129/129（roam-functions 75 + prepush-gate 24 + 补全 19 + 脚手架 6 + repo-references 5；rc 直取）；真 sha 门控：docs-only（0742967→8f7ac9f）rc=1、含 Nix 增量（b960794→0742967）rc=0；钩子端到端——放行路径（真实钩子 + docs-only 增量）0.014s rc=0、新放行说明正确打印；触发路径（本批 38f1d64→2425258，含 flake.nix/钩子/测试）门控正确触发五输出并行求值 rc=0（68s，暖缓存波动区间内）；`nix flake check` rc=0（改动后内容，沙箱 shellcheck-scripts + roam-unit-tests 双确认）；`git diff --check` 干净；**五输出 drvPath 提交前后逐一相同**（38f1d64 vs 2425258，干净树对干净树——flake.nix 仅注释变化的「注释级纯重构」主张实证；checks 输出因引用 `self.outPath` 而移动，符合预期不在对比范围）。

未验证：真实 push 触发钩子（同前，推送仍手动）；macOS Bash 3.2 实机（here-string 自 bash 2.05b 起，3.2 兼容按惯例待第二宿主实证）。

## 2026-09-29 P1 pre-push 差异门控 + roam check 求值并行化（packages/roam.sh + .githooks/pre-push + tests/×3 + README/AGENTS/docs×2，Fedora 44 / WSL2 standalone，本机）

背景：pre-push 五输出求值门槛每次 push 固定串行全量——实测基线 115s（暖缓存、干净树），纯文档提交同价；近 30 个提交里 13 个只动 docs/tests/bootstrap，对五个输出的求值结果零影响。nix eval 是树的纯函数，输入未变的重跑必同结果，跳过无风险；改 Nix 的推送则由并行化削墙钟。

改动：①`cmd_check` 求值并行——各目标相互独立且只读，后台子壳并发求值、mktemp 暂存各自 out/err/rc、`wait` 全部完成后按输入次序汇报（完成次序不定，汇报次序必须稳定可测）、rc 汇总语义不变；`--build` 保持串行（并发 nix build 各自按 max-jobs 展开构建进程，内存/CPU 成倍叠加，只读求值无此成本）；子壳以 if/else 双分支显式写 rc 文件（set -e 下 nix 失败不接住会在落盘前中止子壳）。②pre-push 差异门控：钩子加 BASH_SOURCE 执行守卫（可 source 单测），`gate_needed` 读 pre-push stdin 协议（每行 `<local_ref> <local_sha> <remote_ref> <remote_sha>`）逐 ref 做端点 diff（求值只看推送后最终树，中间提交无关）匹配 `EVAL_INPUT_RE` 闭式清单（`*.nix`、`flake.lock`、`meta.json`、`packages/`、`dotfiles/`——后两者系被 Nix 路径字面量引用进 store 的非 Nix 文件；今后新增此类引用必须同步扩此清单，漏列=误放行）；删除推送（local 全零）放行，新分支（remote 全零）与 diff 失败（sha 缺失）保守跑全量（宁多跑勿漏跑）；全不命中打印说明放行，任一命中 exec 五输出并行求值。③测试：roam-functions 的 cmd_check 断言改次序无关（桩日志排序比对 + 汇报头行次序断言 + 并行预告行——后台子壳竞争写日志），73→75；新增 `tests/prepush-gate.sh` 18 例（git 函数桩 + stdin 协议注入；方向性断言：9 类求值输入命中拦下、近失名/纯文档放行、删除放行且不消费 diff、新分支与 sha 缺失保守拦下、空差异/空 stdin 放行、多 ref 任一命中即拦）；入 run-all → flake checks（shellcheck 关卡 `tests/*.sh` glob 自动覆盖新文件）。④文档同步：roam.sh 头注/usage、docs/roam.md（check 条目 + 测试段补 prepush-gate）、AGENTS.md（CI 段门控描述、目录树两行、双守卫提醒）、README 三处。

验证（本机 Fedora 44 / WSL2 standalone x86_64，用户 xuqihao）：`bash -n` 全过；shellcheck 零告警（`nix shell nixpkgs#shellcheck` 直跑全量改动脚本，沙箱侧另经 shellcheck-scripts 关卡）；run-all 123/123（roam-functions 75 + prepush-gate 18 新增 + 补全 19 + 脚手架 6 + repo-references 5）；钩子实机两路径——跳过路径（0742967→8f7ac9f，纯 docs/VALIDATION.md 增量）0.01s rc=0 打印放行说明；检查路径（b960794→0742967，含 packages/ 等）门控放行进入五输出并行求值 rc=0，逐目标输出/警告正确按目标归组、汇报次序=输入次序。计时：串行基线（改动前、暖缓存干净树）115s → 并行冷缓存（改动后、脏树）83s → 并行暖缓存 63s（-45%；余下受最慢单个求值支配——桌面 toplevel，Amdahl 上限；并发期 Nix 报 git-tree 输入锁等待与 eval-cache busy（ignored），均被正确处理）。`nix flake check` rc=0（shellcheck-scripts + roam-unit-tests 沙箱双确认）；activationPackage 构建 rc=0（roam.sh 过 writeShellApplication 门）；`git diff --check` 干净。

过程教训两条：①新文件不 `git add -N` 就跑 flake check——git 类 flake 源不含未跟踪文件，沙箱里 run-all 找不到 tests/prepush-gate.sh 而失败，外显 signature 为「roam-unit-tests 失败 + shellcheck-scripts cancelled」（与既有老规矩同因，补记 signature 以便下次直接识别）；②验证命令勿把 `nix flake check` 管道接 `tail`——无 pipefail 时链上 rc 取自 tail，失败会被随后的 echo 假确认（首跑即如此，靠 ❓cancelled 线索识破后修正重跑）。

未验证：真实 push 触发钩子（推送仍手动；本机 core.hooksPath 已启用，下次推送即实证——纯文档 push 应秒过、含 Nix 增量 push 应走并行五输出）；`--build` 多目标串行路径仅桩级验证（真构建闭包 6-8GB×多目标，不入验证预算）；macOS Bash 3.2 实机（并行子壳/裸 wait/mktemp 均为 3.2 兼容原语，按惯例待第二宿主跑过才算数）。

## 2026-09-29 P0 两项：旧名可取用 URL 清零入关卡 + roam check 多目标与 pre-push 门槛（bootstrap×4 + sync workflow + README/AGENTS/docs + packages/roam.sh + tests/ + flake.nix + .githooks/，Fedora 44 / WSL2 standalone，本机）

背景：Gitee 仓库实已更名为 nix-roam（origin 即新名；旧名仓库页 302→新名、新名 raw/clone/archive URL 直连 200 均实测）——README/AGENTS「Gitee 路径仍为旧名」系改名前的过时表述。旧名只剩改名重定向撑着：重定向在旧名被他人注册后失效，届时一切仍指旧名的**可取用 URL**（curl|bash、clone、archive 回退、sync 拉源）会取到陌生人内容——供应链风险而非单纯断链。

改动：①13 处可取用旧名 URL 全换新名（README raw×4/clone×2/远程激活×1、bootstrap 四脚本 raw 头注×3/clone×4/archive×3、sync workflow 拉源×1）；README/AGENTS 过时语句改写为新名事实 + 既有检出 `git remote set-url` 建议；顺带修 README 目录树两处陈旧（已删 gc.sh、缺 hosts/_template）。bootstrap 四脚本「既有检出识别」的裸名 alternation（`grep -qE '旧名|nix-roam'`）**刻意保留**——识别旧名时代克隆的 remote，删掉会使旧检出被当异物重克隆。②新增 `tests/repo-references.sh`：跟踪文件零「可取用 URL 形式」（`gitee.com/qihaoxu/<旧名>`——raw/.git/archive/仓库页四前缀共有的域名+路径段）；裸名仅放行 alternation（计数钉死 4 处防「顺手清理」）与 VALIDATION 历史记录；含清单自检（非空≥50/含 README）防空转通过；入 run-all → flake checks → CI 第三层。③`roam check` 多目标：目标可给多个（解析期经 check_attr 校验+去重、保首现次序），逐个跑完再退出、rc 汇总（不在第一个失败处中断——push 前核对应看到全部断点）；`check_attr` 助手与 `host_attr` 分工（显式目标 vs 当前宿主）；usage/头注释/docs/roam.md 同步。④`.githooks/pre-push`：`git config core.hooksPath .githooks` 一次性启用（本机配置不随提交同步，每台推送机各自启用）；钩子 cd 到仓库根后一条 `roam check` 五输出全量求值，任一失败拦下 push，`--no-verify` 跳过一次；只求值不构建（6-8GB 闭包不进 push 路径）。入 shellcheck-scripts 关卡（无 .sh 后缀，显式列出）；.github/SYNC.md 补启用说明；README/AGENTS 的 CI 段由「无 push 前拦截」改为「钩子可选前移第一层」。

过程教训一条：cmd_check 桩的失败注入首跑 5 例假失败——`FAIL_ATTR` 空串作 case 模式等价 `**`（匹配一切），全部 nix 桩调用被注入 rc=4；桩加非空守卫后全绿。空串模式匹配一切属 shell case 语义盲区，已记入用例注释。

验证（本机 Fedora 44 / WSL2 standalone x86_64，用户 xuqihao）：`bash -n` 全过；shellcheck 零告警（roam.sh/补全/tests/bootstrap/钩子——即关卡新命令行全量）；run-all 103/103（roam-functions 73 + 补全 19 + 脚手架 6 + repo-references 5；rc 直取）；**负例**：/tmp 副本（git archive HEAD + 注入一条旧名 URL）→ repo-references FAIL rc=1（顺带把 HEAD 存量旧名 URL 七文件全数点名，检出能力双重确认）；实机 `bash packages/roam.sh check wsl nixos` rc=0（次序正确+汇总行）、`check bogus` / `check --bogus` rc=1；钩子实机自 docs/ 子目录执行（样例 ref 行 stdin）rc=0——五输出求值全过即本批五输出 drvPath 验证（roam.sh 文本变更随含它闭包的 drvPath 移动）；`nix flake check` rc=0（shellcheck-scripts 含新钩子文件、roam-unit-tests 含新关卡——沙箱层双确认；两新文件先 `git add -N`，老规矩）；activationPackage 构建 rc=0（改动 roam.sh 过 writeShellApplication 门）；`git diff --check` 干净；README/AGENTS→.github/SYNC.md、docs/roam.md 链接目标存在。

未验证：真实 push 触发钩子（推送仍手动；本机已启用 core.hooksPath，下次推送即实证，异常则记新条）；CI 实跑（同前，Gitee 同步后事后层）；macOS / aarch64 实机（同前）；Gitee 旧名重定向失效场景（外部依赖不可制造——关卡+文档已把暴露面收敛到 4 处 alternation 与历史记录）。

## 2026-09-28 NixOS 侧 roam switch 实机首跑——预检/安装位/断言三项遗留关闭（检出 ≥b9c3cea 的 roam 变更实机激活，NixOS-WSL 26.11 x86_64，主机 wsl；记录自用户实跑输出转记）

范围：NixOS-WSL 主机对含 hostname 预检（a1401d0）与 gc 折入（200e441）的检出执行 `roam switch`。实跑 rc=0（run_logged 的「完成」仅在 rc=0 打印）：19 个派生构建、12 路径经 NJU 镜像替换、激活与 bootloader 登记完成、全程无 stc exit 4（getty mask 与 linger 在位——闭包可见 `unit-console-getty.service-disabled`）；dix 差异 2110→2110 路径（+12/-12、+4.69 KiB，与 standalone 侧同批切换同幅 = 同一 roam 包内容）；`ShellCheck-0.11.0` 被取入构建环境——writeShellApplication 门在 NixOS 侧真实执行（三个 roam.drv：文本装配 + 检查 + symlinkJoin 外壳）。

就此关闭的未验证项：①`nixos_preflight` 实机执行（P3 遗留——cmd_switch NixOS 分支必经预检方到 nh，rc=0 即通过）；②NixOS 侧安装位的 roam 变更激活（自 P1 批起多笔「该侧下次 switch 生效」——WSL 侧安装的 roam 自此含守卫分发、gc 折入、预检全部内容）；③hostnameGuard 断言过真实 NixOS toplevel 构建（此前仅 /tmp 负例与求值层证据）。

观察一条（既有、非本批引入）：system-path 构建期 buildEnv 报 `python3-3.13.15-env/bin/ninja` 与 `ninja-1.13.2/bin/ninja` 碰撞（ignored）——系统级碰撞仅告警不失败（与 HM 用户级致命冲突不同，见 AGENTS buildEnv gotchas），源于 Python 科学环境携带 ninja；良性留观，日后收拾 nixos-base 时可从 python env 摘除。

未验证（全局剩余）：`--system` 真清理与 sudo 实际执行（破坏性操作，桩级为止）；macOS / aarch64 实机（等硬件）；桌面机（hosts/nixos）实机——与 WSL 同一 NixOS 分支，无独立代码路径。

## 2026-09-28 NixOS 侧复验 gc 折入 + gc 用例宿主漂移修复（tests/roam-functions.sh，NixOS-WSL 26.11 / wsl，本机）

背景：gc 折入（200e441）的验证在 Fedora/WSL standalone 完成，上条记录留了「NixOS 分支的 gc（NixOS 自动 --system 的真机行为）——NixOS 侧下次顺手」未验证项；本次在 NixOS-WSL 主机上复验即补此层。

发现：真机复跑 run-all 77 例中 1 例**假失败**——`gc：无 --system 不调 sudo` 隐含假设宿主非 NixOS：`cmd_gc` 经 `is_nixos()`（探测 `/etc/NIXOS`）在 NixOS 上自动 `system_gc=true`，桩 sudo 被真实调用。用例语义随运行宿主漂移，属测试缺陷非 roam 缺陷（roam.sh 侧行为完全符合设计）。

修复：`gcr` 桩内固定 `is_nixos() { return 1; }`——既有 13 例钉死 standalone 语义，真机是 NixOS 也不再漂移（SC2329 豁免文件头已有）；新增 `gcr_nixos`（桩 return 0）3 例：NixOS 无旗标自动 --system（先用户后 `sudo -H --`）、NixOS dry-run 含 sudo 侧零执行——roam-functions 57 例，合计 82。

验证（本机 NixOS-WSL 26.11 x86_64，主机 wsl，用户 xuqihao）：run-all 82/82；`nix flake check` rc=0（含 shellcheck-scripts 对改动文件 + store 副本单测）；真机 NixOS 侧 `bash packages/roam.sh gc --dry-run` 于**检出目录外**跑 rc=0——环境标签正确判 NixOS（is_nixos 优先于 is_wsl）、自动 --system 打出两段命令（用户侧先、`sudo -H --` 系统侧后）、gc_bin 经真 PATH 解析为 `/run/current-system/sw/bin/nix-collect-garbage`、dry-run 零执行。上条「NixOS 分支的 gc（真机 dry-run 层）」未验证项就此关闭。

未验证：`--system` 真清理路径与 sudo 实际执行（破坏性操作，同前桩级覆盖为止）；macOS 侧（同前）；桌面机（hosts/nixos）实机——行为同 NixOS 分支，无独立代码路径。

## 2026-09-28 gc 折入 roam + 脚手架样例块检查（packages/roam.sh + tests/ + bootstrap/gc.sh 删除 + 六处文档，Fedora 44 / WSL2 standalone，本机）

背景：`bootstrap/gc.sh` 是 day-2 运维工具混在 day-0 安装器里——P2 拆分时其文档已留在 AGENTS「Garbage collection」而非 docs/bootstrap.md（无意识承认非引导链），且它是唯一被闭包内 roam 依赖的 bootstrap 脚本，迫使 `roam gc` 这个机器操作要求检出目录；其自带宿主探测与 roam.sh 重复且不承重（安装脚本的重复有 curl 单文件刚需撑着，gc 没有）。

改动：①gc 逻辑（~120 行）折入 `packages/roam.sh` 的 `cmd_gc`（参数解析、宿主标签复用既有 is_nixos/is_wsl、SUDO_USER 守卫、gc_bin 三级 PATH 兜底、先用户后系统、dry-run），`--older-than Nd/--all/--system/--dry-run/-h` 语义逐项保留；`roam gc` 不再 repo_check（与 rollback/info 同族的「机器操作」）；`bootstrap/gc.sh` 删除，等价直跑 `bash packages/roam.sh gc`。README（roam gc 行 + 手动垃圾回收节）、AGENTS（目录树 + GC 节）、docs/roam.md 三处、补全头注释、profiles/nixos-base.nix 注释同步。②新增 `tests/scaffold-blocks.sh`：grep 级断言 bootstrap/nixos.sh 打印的两块样例各含 `hostnameGuard "__HOSTNAME__"`、桌面/CLI 的 nixHome 分野、Hermes 只在桌面块、hosts 接线计数——挡「改 flake 忘改脚手架」类漂移（hostnameGuard 就漏过一次）。③tests 补 gc 桩例 13 个（假 nix-collect-garbage/sudo 经 PATH 打桩、参数落 GC_LOG：dry-run 只打不执行、缺省 14d、--older-than 30d、--all→--delete-old、--system 两段调用序、--help、五组拒绝路径），合计 77 例。

过程教训一条：从补全 harness 复制的 `expect_contains` 是空格定界匹配，gc 的「执行：」行 gc_bin 为完整路径（前邻 `/`），断言假失败——补无边界 `expect_sub` 助手区分两种语义。

验证（本机 Fedora 44 / WSL2 standalone x86_64，用户 xuqihao）：`bash -n` / shellcheck（roam.sh 增至 ~860 行）零告警；run-all 77/77；**检出目录外**实跑 `bash packages/roam.sh gc --dry-run` rc=0（当前环境标签正确、PATH 兜底真实生效——本 shell 即经 `/nix/var/nix/profiles/default/bin` 找到 gc_bin）、`--dry-run --system` 打印用户+sudo 两行不执行、`--older-than 0d` 拒绝 rc=1；五输出求值全过（roam.sh 变更移动全部含它闭包的 drvPath）；`nix flake check` rc=0——中途红一次系新文件 `tests/scaffold-blocks.sh` 未 `git add -N`、Git Flake store 副本缺该文件（本文件早有记载的老坑复发，沙箱层比本地直跑多拦一道，正是关卡意义）；activationPackage 构建过 writeShellApplication 门；`roam switch` 实机 rc=0、终态一致；安装版 `~/.nix-profile/bin/roam gc --dry-run` 检出外无管道 rc=0（管道接 head 的 rc=141 系 SIGPIPE，验证手法问题非缺陷）。

未验证：`--system` 真清理路径与 sudo 实际调用（桩级覆盖调用序，真机执行属破坏性操作不跑）；NixOS 分支的 gc（NixOS 自动 --system 的真机行为——NixOS 侧下次顺手）；macOS 侧（同前桩级）。

## 2026-09-28 双推后自查：四处修正 + 脚手架端到端模拟（AGENTS.md + packages/roam-completion.bash + flake.nix + README.md，Fedora 44 / WSL2 standalone，本机）

自查发现并修正：①AGENTS.md 架构图四安装点之一的 `modules/desktop/programs.nix` 系 2026-09-26 拆档（4342a57）前的残留，实际导入点是 `modules/desktop/core.nix`——P2 搬运未扫到该节，属前史问题非当日引入；②roam-completion.bash 头注释「改动后手动自查」在 fc18a739 建关卡后已失准——当日只改了 roam.nix 的同义注释，漏了补全文件自身头部，改指 shellcheck-scripts 关卡；③shellcheck-scripts 命令行补入 `packages/roam.sh`（writeShellApplication 构建门之外的第二重覆盖，`nix flake check` 单独跑也能拦住）；④README `roam switch` 说明补 NixOS 预检一句。

脚手架端到端模拟（补 P3「未验证」里最近的一层）：/tmp 完整副本 + `cp -r hosts/_template hosts/newhost` + sed 替换占位符 + 把 bootstrap/nixos.sh heredoc 打印的样例块 A（hostnameGuard 随 sed 变为 newhost）按用户粘贴路径插入 flake.nix → `.#nixosConfigurations.newhost.config.networking.hostName` 求值 = "newhost"、toplevel drvPath 求值 OK（hostnameGuard 断言通过）——「新主机脚手架 → 粘贴样例 → 求值」整链实证。过程两次踩到已知/新知：Git Flake 纯度要求对新 hosts/ 目录 `git add -N`（VALIDATION 早有记载）；本机 nix-instantiate `--parse`（Determinate Nix 3.22.2）实际做变量解析而非纯语法解析——样例块单独解析须完整绑定 outputs 函数头变量，改为真插 flake 求值，验证反而更强。

验证：`actionlint` 对两个 workflow 通过（eval.yml 改动的 YAML/模式有效）；shellcheck-scripts（新命令行含 roam.sh）构建 rc=0；`nix flake check` rc=0；run-all 51/51；陈旧引用扫描（programs.nix 等，剔除历史记述行）零残留。

未验证：**CI 实跑**——本机 gh 未登录、GitHub API 出口 IP 限流无法侧读，需在 Actions 页人工确认（eval.yml 第三步 `nix flake check` 的首次实跑即在本批之后）；其余同前（NixOS 侧预检实机、darwin/aarch64 实机）。

## 2026-09-28 P3 hostname 约定双重守卫（flake.nix + packages/roam.sh + bootstrap/nixos.sh + tests/ + AGENTS/README/docs/roam，Fedora 44 / WSL2 standalone，本机）

改动：①flake 侧新增 `hostnameGuard "<输出属性名>"` 内联模块（let 内与 `nixosHome` 同款风格）——「目录名 = networking.hostName = 输出属性名」由隐性约定改为 NixOS assertion，两个 NixOS 输出的 modules 列表各带一份；`bootstrap/nixos.sh` 脚手架打印的两块样例输出同步自带该守卫，新主机复制即得。②roam 侧新增 `nixos_preflight`：`roam switch` NixOS 分支在派发 nh 前求值 `.#nixosConfigurations.<短主机名>.config.networking.hostName`——求值失败（无对应输出）或值不等（hostName 脱节）分别 die，报错指向约定/脚手架与两侧对齐修法，替换 nix/nh 难懂的属性缺失原始报错。③tests 补 3 个桩例（PATH 注入假 nix + uname -n 函数桩：一致 rc0 / 无输出 rc1 / 不一致 rc1），51 例。AGENTS（加机步骤 3 + Quick rules）、docs/roam.md、README 约定句同步。

实测纠偏（注释层）：初稿把 assertions 写成「构建期拦截、求值 drvPath 不触发」——读锁定 nixpkgs 源码 `lib.asserts.checkAssertWarn`（top-level.nix:78 消费 `config.assertions`）并负例实测后确认其在 **toplevel 求值期 throw**；flake/roam/docs 三处注释已按事实改写：断言覆盖 nix eval drvPath（含 CI 第一层）、任何构建与切换全部路径，预检的价值是「早一步 + 报错直接给修法」。编辑过程另有一次注释替换把函数头复打成两行，`nix-instantiate --parse` 当场拦截。

验证（本机 Fedora 44 / WSL2 standalone x86_64，用户 xuqihao）：`bash -n` / `--parse` / shellcheck 零告警 / `run-all` 51/51（rc 直取）；五输出求值全过（两侧 toplevel 求值即过 checkAssertWarn 断言路径）；两侧 hostName 求值 = "nixos" / "wsl"（预检求值的同一属性路径）；**负例**：/tmp 完整副本改 hosts/wsl hostName 为 wrongname → `nix eval …toplevel.drvPath` rc=1，报错逐字显示 hostnameGuard 断言文本；`nix flake check` rc=0；activationPackage 构建 rc=0（新 roam.drv 过 writeShellApplication 门）；`bash packages/roam.sh switch` 实机 rc=0 落世代、`roam status` 终态一致。

未验证：`nixos_preflight` 实机执行（本机 standalone，NixOS 分支仅 3 桩例 + 其求值属性路径的实机求值间接覆盖；NixOS 侧下次 `roam switch` 顺手跑一次即闭合）；脚手架打印效果（nixos.sh 仅改 heredoc 样例文本，无逻辑改动）；hostname 错配下 `roam status`/`check` 的行为（走 nix 原始报错，已知边界）。

## 2026-09-28 文档拆分 P2：机制细节出 AGENTS/README 落 docs/ 三页（docs/{roam,mirrors,bootstrap}.md + AGENTS.md + README.md，纯文档改动）

改动：结构原则 = README 用法 / AGENTS.md 规则 / docs/ 原因与机制。新增 `docs/roam.md`（roam 打包与安装位、宿主探测与用户守卫、nh 双侧后端语义、世代/漂移/回滚、子命令速查、补全机制、WSL stc-exit-4 两来源、测试与沙箱发现）——吞 AGENTS.md「Build & activate commands」的切换长段与「NixOS-WSL」的 getty-mask/linger 两段；`docs/mirrors.md`（CERNET 聚合器、substituter 单源、rainbow-delimiters 事件、cachix 公钥归属、npm registry、bootstrap 写入机制、已死镜像考古）——吞 AGENTS.md「China mirrors」整节与 README 注意事项的镜像长注；`docs/bootstrap.md`（统一入口、linux.sh 七步与两种安装模式/建号交互/wsl.conf 合并、darwin.sh、nixos.sh install/adopt）——吞 AGENTS.md 引导节四条巨弹。AGENTS.md 对应位置改短规则 + 链接（保留的规则含：无切换别名、检出目录约束、目录名=hostname=输出名、镜像单源与公钥归属、bootstrap 写入机制两侧同步、flake inputs 不指向死镜像、BASH_SOURCE 守卫勿删）；README 镜像注压缩为结论 + 手工补缓存命令块（用户侧操作保留）+ 链接，roam/bootstrap 两处加 docs 指针；两处目录树改 docs/ 行。措辞以机械搬运为主，仅连接句与标题新写。

验证：纯文档标准——逐文件相对链接解析 16/16 全通（README×6 / AGENTS×5 / 三 docs 页×5，含跨目录 `../AGENTS.md`）；孤儿引用检查（sysadminctl / wsl_conf_merge / LwCD 等被移短语在 AGENTS.md 与 README 正文零残留，仅存于新页与 VALIDATION 历史记录）；`git diff --check` 干净。无 Nix 求值影响（docs 不进任何闭包；shellcheck-scripts 与 roam-unit-tests 的输入文件未动）。

未验证：无（文档 pass，无重建/激活项）。

## 2026-09-28 bootstrap 纳入 shellcheck 关卡 + 上批 flake check 结论更正（bootstrap/{linux,gc}.sh + tests/roam-functions.sh + flake.nix + AGENTS.md，Fedora 44 / WSL2 standalone，本机）

改动：`bootstrap/*.sh` 纳入 `shellcheck-scripts` 关卡（flake.nix 命令行补入，AGENTS CI 段措辞同步）。两处告警均为 SC1091「无法跟随运行时才存在的 source 路径」的固有误报：linux.sh 原有豁免注解把代码写错（SC1090 ≠ SC1091，警告正是由 SC1091 报出），改对并注明理由；gc.sh 的 `/etc/os-release` 读取处新补同款豁免。

更正（上一条记录的验证结论）：上批「`nix flake check` 全过」对**提交后的树**不成立——$BASH shebang 的 `printf` 单引号内字面 `$HM_STUB_FILE` 触发 SC2016（info 级），而我复验时用 `nix flake check | tail && echo OK` 取 rc，拿到的是 tail 的退出码——本文件 2026-09-28 早些时候刚记载过的同款教训（「验证命令的 rc 不得经管道取」）当场重犯。影响范围仅此一项：activationPackage 构建（writeShellApplication 门只查 roam.sh）与 roam-unit-tests（沙箱跑测试不跑 shellcheck）两结论不受影响；已激活的世代 id 33 其 roam.sh 文本不涉 SC2016，无需回滚处理。本批补 SC2016 豁免（字面量系 stub 本体需要，其运行期才展开）。

验证（本机 Fedora 44 / WSL2 standalone x86_64）：`nix shell nixpkgs#shellcheck` 对 roam.sh / 补全 / tests/*.sh / bootstrap/*.sh 零告警；改动脚本 `bash -n` 过；`bash tests/run-all.sh` 48/48（rc 直取）；`nix flake check` rc=0（输出落临时文件、rc 不经管道——手法本身即本条教训的落实；该命令已含新 glob 的 shellcheck-scripts 沙箱构建）。

未验证：CI 在本批提交上的运行（同上批：Gitee 同步后事后跑，eval.yml 变更需手动双推生效）；bootstrap 脚本行为未动（仅注释行），引导链路无需重跑。

## 2026-09-28 编辑残留清理 + roam 单测/补全 harness 进仓（packages/roam.{nix,sh} + tests/ + flake.nix + eval.yml，Fedora 44 / WSL2 standalone，本机）

改动：两部分。①残留——roam.sh NixOS 分支的 nh 缺失提示改指 cli-dev 共享列表（原提示仍指向 2026-09-28 已退役的 `programs.nh.enable`，standalone 分支此前已改对）；flake.nix 删除 electron-41.9.1 近逐字重复的注释块（保留带探针验证细节与 nixos-base 指针的一份）；VALIDATION.md 复原 4e7a8af 条目失落的 `##` 标题行（与 git 历史逐字比对确认仅缺该行）。②测试基建——roam.sh 分发段加 `${BASH_SOURCE[0]} = $0` 执行守卫（source 加载不分发、直跑照旧），`system_generation_ids` 的 profile 目录可用 `ROAM_SYSTEM_PROFILES_DIR` 重定向；新增 `tests/`：roam-functions.sh（纯函数单测 29 例——meta_username 好坏样本、standalone_target 架构矩阵（uname 打桩、kernel 捕获期重 source）、nixos_output、load_hm_generations（PATH 注入假 home-manager 喂 fixture，含 rollback 同路径重复世代语义）、system_generation_ids（临时目录 + 噪声过滤）、choose_inputs（fixture flake.lock + stdin 管道，编号/名称/逗号混用/越界拒绝））+ completion-harness.sh（模拟 COMP_WORDS/COMP_CWORD 直调 `_roam` 19 例；世代号宿主相关只断言旗标，update 输入名读真 flake.lock 只做成员断言）+ run-all.sh 汇总 + fixtures/；flake 新增 `checks.{x86_64,aarch64}-linux`（显式两系统，不做 forAllSystems）：`shellcheck-scripts`（补全文件与 tests/*.sh 静态关卡——堵上 writeShellApplication 门外的洞）与 `roam-unit-tests`（`ROAM_TEST_REPO` 指向 store 副本跑 run-all）；CI eval.yml 加第三步 `nix flake check`。AGENTS/README/roam.nix 注释同步。

沙箱实测发现两条（已固化进代码注释）：①构建沙箱 PATH 上的 `bash` 是 stdenv 极简构建（无 progcomp，`compgen` 不可用；沙箱外同一锁定 rev 的 bash-interactive 正常）——roam-unit-tests 的 nativeBuildInputs 须带 `bashInteractive`；②沙箱无 `/usr/bin/env`，stub 脚本 shebang 以 `$BASH` 绝对路径生成，固定 `#!/usr/bin/env bash` 在 flake checks 里跑不起来。

验证（本机 Fedora 44 / WSL2 standalone x86_64，用户 xuqihao）：编辑文件 `bash -n` / `nix-instantiate --parse` 全过；`nix shell nixpkgs#shellcheck` 对 roam.sh / 补全 / tests 三脚本零告警（tests 的 SC2030/2031/2329 系打桩固有误报，文件级豁免并注明理由）；`bash tests/run-all.sh` 48/48 全过（本地，函数单测 29 + 补全 19）；五输出求值全过，`checks.aarch64-linux` 两 check 亦求值过；`nix build .#checks.x86_64-linux.shellcheck-scripts` 与 `.#checks.x86_64-linux.roam-unit-tests` 沙箱构建真 rc=0（后者即补全 harness 在沙箱内 19/19）；`nix flake check` 全过；activationPackage 构建真 rc=0（双 roam.drv 过 writeShellApplication 门，1499 路径 +512 字节）；`bash packages/roam.sh info` / `switch` 实机直跑（执行守卫未破坏直跑分发），switch 真 rc=0 落世代 id 33、switch-*.log 带头部、补全文件随新包落位 `~/.nix-profile/share/bash-completion/completions/roam`；`~/.nix-profile/bin/roam status` 终态一致；`git diff --check` 干净。

未验证：CI 在本批提交上的运行（Gitee 同步后事后跑；且 eval.yml 属 workflow 文件，需本机凭据手动双推 Gitee 与 GitHub 后新步骤才生效——GITHUB_TOKEN 推不动）；补全 harness 与真实 TAB 键的等价性（与既往同界，模拟 COMP_WORDS/COMP_CWORD）；bootstrap/*.sh 未纳入 shellcheck-scripts（实测存量 5 处告警，纳入前需先清零，另行一批）；NixOS 侧（桌面/WSL）安装位本次未激活——roam.sh 文本变化已进其闭包，下次该侧 `roam switch` 生效。

## 2026-09-28 NixOS 侧 roam 四项遗留实测 + 世代号读取纠偏（packages/roam.sh + packages/roam-completion.bash，NixOS-WSL 26.11 x86_64，本机 wsl）

复验范围：前四条「未验证」清单的 NixOS 部分——补全实机效果（559861a）、nh 经 cli-dev 落系统安装位（b779f51）、status/doctor/rollback 的 NixOS 路径（fb20037）、nrs/hms 在新 bashrc 消失（8a989c7）。

实测纠偏（改动 ba6947f，两处）：① NixOS 侧世代号读取的三个消费点（doctor 计数、`rollback --list`、补全）原走 `nix-env -p /nix/var/nix/profiles/system --list-generations`——非 root 因取不到 profile 锁（`system.lock` Permission denied）**静默列空**（doctor 退化为「无法列出」warn、`--list` 空表、补全只剩旗标）；且补全分支的 sed 锚 `^[0-9]` 对 nix-env 前导空格右对齐的输出**永不匹配**，root 也拿不到号（standalone 走 home-manager 分支故未暴露）。改为 glob `/nix/var/nix/profiles/system-*-link` 直读：profiles 目录与链接全局可读，日期取链接自身 mtime（GNU stat 不跟随，与 nix-env 同源逐字一致），当前世代以 `readlink system` 为准；roam.sh 抽 `system_generation_ids()` 供 doctor/`--list` 共用，补全文件内同款小循环（入口级重复系惯例）。② 补全首版修法 `${cgen##*/system-}` 对无斜杠的 `system-15-link` 永不匹配（模式含字面 `/`）→ 当前世代漏排除，单步复现后改 basename + 整串比较。

验证（实机，用户 xuqihao）：两文件 `bash -n` + ShellCheck 0.11.0 零告警（补全文件绕过构建门，按其头部注释手工查）；切换前五输出求值全过（`roam check` 缺省 + 四显式目标，CI 第一层）；三次 `roam switch` 真 rc=0——gen 15（pd9ysa7c…，落 559861a；dix roam ×3、+11/-9、+5.85 KiB）、gen 16（szp6g747…，落 ba6947f；+12/-12、+1.91 KiB）、回滚后复切（同路径复用 system-16-link 不新增世代号，与既往记载一致），均走完激活+bootloader 全链、switch-*.log 带头部落盘。安装位实测：补全文件随 system sw 落位（`/run/current-system/sw/share/bash-completion/completions/roam` → symlinkJoin 外壳）；全新干净登录 shell（`env -i … bash --login -i`）内 `_comp_complete_load roam` 懒加载成 `complete -F _roam roam`，13 用例 harness 全过——一级八子命令+help、`ch`/`-` 前缀、check 旗标+五目标+旗标后补目标、update 经 jq 实时读 flake.lock 补六输入名、rollback 旗标+**用户态**世代号 6–15（当前 16 排除）、gc 四旗标与 `--older-than` 取值、switch/status/未知子命令空补全；`nh` 于 `/run/current-system/sw/bin/nh`（经 profiles/cli.nix 接线，`programs.nh.enable` 已删后两代均正常）；`type nrs`/`type hms` 未定义、`ll` 存留、HM 生成 bashrc 零 nrs/hms 残留。status NixOS 分支：漂移（改动未切）→ 一致（切换后）两态均实测；doctor 用户态全绿（927G 余量、11 世代、六镜像 HTTP 200/301/302、漂移一致、systemd 零失败单元；0 失败 0 提醒 rc=0，doctor-*.log 落盘）；`roam rollback --list` 用户态完整表（日期与 nix-env 同源、当前标记）；`roam rollback --yes` 实机 rc=0——`sudo nixos-rebuild switch --rollback` 全链（profile 16→15、激活完成、`/run/booted-system` 不动属预期——下次 WSL 重开按 profile 引导，复切后已指回 gen 16），rollback-*.log 带头部；回滚后 status=漂移（NixOS 分支为两态判定，「已回滚」三态系 standalone 专属——HM activate 重登记世代号的语义在 NixOS 无对应物）。终态：profile=system-16-link、运行=检出、status=一致、零失败单元。

未验证：WSL 补救提示分支（仅 nh 失败路径触发）；真实键盘 TAB（harness 模拟 COMP_WORDS/COMP_CWORD，与 standalone 侧验证同界）；desktop 输出实机构建/激活（需桌面主机）；darwin/aarch64 实机；CI 在本批提交上的运行；`roam rollback N` 显式世代号路径（与 `--rollback` 同命令族，未另测）。

## 2026-09-28 roam 附带 bash 子命令补全（packages/roam.nix + packages/roam-completion.bash + AGENTS/README/cli-dev 注释，Fedora 44 / WSL2 standalone，本机）

改动：`packages/roam.nix` 由裸 `writeShellApplication` 改为 `symlinkJoin`——同一包内合并 `bin/roam`（原 writeShellApplication 主体及其 bash -n + shellcheck 门不变）与新文件 `packages/roam-completion.bash`（→ `share/bash-completion/completions/roam`）。补全内容：一级补全八个子命令 + help/-h/--help；二级——`check` 补 `--build` 与五个目标名，`update` 经 jq 实时读 `flake.lock` 的 `.nodes.root.inputs` 键补输入名（无 jq/无 lock 时只补旗标，与 cmd_update 同款降级），`rollback` 按宿主补世代号（NixOS `nix-env -p /nix/var/nix/profiles/system --list-generations` / standalone `home-manager generations`，均排除 current）+ `--list`/`-y`/`--yes`，`gc` 补 `--dry-run/--all/--system/--older-than`（`--older-than` 后补 7d/14d/30d 示例值）；`switch/status/doctor/info` 无自有补全（switch 透传 nh 不猜第三方旗标）。机制与免接线依据（两侧均实测）：bash-completion（本机 2.18.0，懒加载入口 `complete -D -F _comp_complete_load`，搜索含 `bash_completion:3575` 的 `$XDG_DATA_DIRS` 各 `bash-completion/completions/`）——standalone 侧 HM 把 `~/.nix-profile/share` 注入 XDG_DATA_DIRS；NixOS 侧 `environment.pathsToLink` 默认含 `/share/bash-completion`（对 `.#wsl` 求值实测）。补全文件不经过 writeShellApplication 的检查门（writeTextDir 无 gate），注释已标注改动需手动自查。

验证（本机 Fedora 44 / WSL2 standalone x86_64）：`bash -n` 过；17 用例功能 harness（模拟 COMP_WORDS/COMP_CWORD 调 `_roam`）全过——一级子命令、`ch`/`-` 前缀、check 目标与 `--build`（含旗标后补目标 `--build ws→wsl`）、update 六输入名、rollback 旗标+本机 HM 世代 id 13–29（排除 current）、gc 四旗标与 `--older-than` 取值、switch/status/未知子命令空补全（首跑 1 例 FAIL 为 harness 自身 cword 传错，修正后 17/17）；五输出求值全过（`roam check` 缺省 + 显式 wsl/nixos/aarch64-linux/aarch64-darwin，CI 第一层）；`roam check --build` activationPackage 构建真 rc=0（闭包出现两个 roam.drv：writeShellApplication 内层 + symlinkJoin 外壳）；`roam switch` 实机激活真 rc=0（dix：roam ×3、+4/-2 路径、+5.85 KiB）；激活后端到端——`~/.nix-profile/share/bash-completion/completions/roam` 落位、全新登录 shell 内 `_comp_complete_load roam` 懒加载成功（`complete -p roam` → `complete -F _roam roam`）、`roam che`→[check]、`roam update <TAB>`→六输入名+旗标、XDG_DATA_DIRS 含 profile share；`roam status` 终态一致（id 31）且新包下 `roam` 二进制正常。过程要点：新文件需先 `git add -N` 才能被 Git Flake 求值读到（首轮流五个求值全败于此，属预期纯度行为）。

未验证：NixOS 侧（桌面/WSL）实际 TAB 效果——`/share/bash-completion` 在默认 pathsToLink 内已求值确认，补全文件随 system sw 落位，实机体验留给该侧下次 `roam switch` 后的新开 shell；darwin/aarch64 同前（仅求值）；macOS 原生 zsh 本就不在管理范围（补全只作用 bash）。

## 2026-09-28 roam switch standalone 后端迁移至 nh home（packages/cli-dev.nix + profiles/nixos-base.nix + packages/roam.sh，Fedora 44 / WSL2 standalone，本机）

改动：standalone 侧切换后端由 `home-manager switch --flake .#<系统>` 换为 `nh home switch --diff always --configuration <系统> .`（NixOS 侧 nh os 路径不变），双侧统一同一 nh 前端（nom 构建 + dix 世代差异）。nh 自 `profiles/nixos-base.nix` 的 `programs.nh.enable` 移入共享 `packages/cli-dev.nix` 单源（该模块除装包外无作用；四安装点同包，当前锁定 nixpkgs 为 nh 4.4.2）。语义边界（读 nh 4.4.2 上游源码确认）：nh home 不 exec home-manager CLI——自建 activationPackage 再直接跑其 `activate`，世代登记语义与 hm switch 相同，`roam status`/`rollback`/`doctor`（`home-manager generations` 枚举）不受影响；代价：HM news 不再显示、激活日志缺省隐藏（排障加 `--show-activation-logs`）。home-manager CLI 保留（bootstrap 安装位），`home-manager switch` 仍是有效手工回退/自举路径。

实测纠偏一点（已固化进代码注释）：nh 4.4.2 把裸 `.#attr` 安装目标解析成 `packages.<system>.<attr>` 简写而非 homeConfigurations 属性——首跑 `roam switch` 即栽在此（nix 报 does not provide attribute 'packages.x86_64-linux.x86_64-linux'）；改用 `--configuration <系统名>` + 位置参数 `.` 后通过（nh 上游 master 已重写该解析，nixpkgs 升 nh 后需复验命令形式）。

验证（本机 Fedora 44 / WSL2 standalone x86_64）：`bash -n`；五输出求值全过（含 darwin 输出确认 nh 在 darwin 求值无碍、nixos/wsl toplevel 在移除 programs.nh.enable 后求值通过）；activationPackage 构建真 rc=0（nh 4.4.2 与新 roam.drv 进闭包，roam.sh 过 ShellCheck 门）；实机激活三步——① `home-manager switch --flake .#x86_64-linux` 自举把 nh 装进 profile（顺带实证该路径显示的 "406 unread news items" 正是 nh 路径不再展示的输出）；② `nh home switch --diff always --configuration x86_64-linux .` 直跑真 rc=0（nom 构建、dix 差异 +3/-3 路径即修正版 roam.sh 的变化、激活落世代）；③ 安装后的 `roam switch` 入口真 rc=0（run_logged「完成」仅 rc=0 打印；dix 差异 0=树未再动、同内容重登记新世代号——与同日 rollback 条目同一已知语义）。终态 `roam status`=一致（运行世代 id 30 = 检出求值）、`roam info` 新目标行正确（nh 可用 / home-manager 标注为世代枚举用）、`roam doctor` 世代枚举正常（18 世代，最老 2026-09-17）。

未验证：NixOS 侧（桌面/WSL）nh 经 cli-dev 列表落地（替代原 programs.nh.enable）——两 toplevel 求值通过，nh 随 profiles/cli.nix / modules/desktop/core.nix 必然进 systemPackages，实机激活留给该侧下次 `roam switch`（切换前后世代均另有 nh，无自举缺口）；darwin/aarch64 实机同前（桩级 / 仅求值）。

## 2026-09-28 roam 新增 status/doctor/rollback 与切换日志（packages/roam.sh，Fedora 44 / WSL2 standalone，本机）

改动（借鉴 omarchy 的 version/debug 意识与日志习惯，映射到 Nix 语义）：`roam status` 漂移检测——检出求值（activationPackage/toplevel 的 outPath）对比运行世代（standalone 取 `home-manager generations` 的 `(current)` 世代、NixOS 取 `/run/current-system`），三态结论 一致 / 已回滚或检出已回退 / 漂移，附 git 提交与脏标记；`roam doctor` 只读体检（用户守卫、/nix 余量、世代数与最老年代、meta.json 的 substituters 逐个 curl 可达性、漂移、NixOS failed units），结果落 `~/.local/state/nix-roam/doctor-*.log`，仅 ✗ 致退出 1；`roam rollback [N|--list]` standalone 经 `<gen>/activate` 重激活旧世代（y/N 确认、--yes 跳过）、NixOS 走 `sudo nixos-rebuild --rollback / --switch-generation N`（nh 无回滚入口）；switch/rollback 全程 tee 到同目录 `switch-*.log`/`rollback-*.log`（与 bootstrap 链同源）。抽出 host_attr / compute_drift / run_logged / load_hm_generations 复用；解析只用 bash 内建与 sed/grep（目标机可能无 awk，与 gc.sh 同款约束）。

实测纠偏两点（已固化进代码注释）：① HM 的 `activate` 会把旧内容登记为**新世代号**（回滚到 id 21 的内容后出现同 store 路径的 id 23），因此「已回滚」判定必须比对任一历史世代而非仅最新一条，且缺省回滚目标须跳过与当前同路径的重复世代；② doctor 文案避免与 verdict 自带的「漂移」前缀重复。

验证（本机 Fedora 44 / WSL2 standalone x86_64）：`nix shell nixpkgs#shellcheck` 零告警（含修掉 3 处 SC2004 样式级，writeShellApplication 对任何级别都会失败）+ `bash -n`；status 三态实测——漂移（改 roam.sh 未切）、已回滚或检出已回退（代码保持不动：switch → rollback → status 正确引用历史世代 id）、一致（终态）；doctor 全项通过（922G 余量、9 世代最老 2026-09-17、六镜像 HTTP 200/301/302 全可达、漂移以 ! 提醒不致败）且日志落盘；rollback 实测 y 确认回滚（旧内容登记为新 id）、EOF 取消 rc=0、--list 表格带 (current) 标记；switch 日志含头（date/cmd）与全输出；五输出求值全过 + activationPackage 构建 + 最终 switch 均真 rc=0，终态 status=一致。

未验证：NixOS 侧 status（`/run/current-system` 对比）、doctor 的 systemd 段、rollback 的 nixos-rebuild 路径——均需 NixOS 实机（该侧下次 `roam switch` 后顺手各跑一次即可补齐）；macOS 桩级同前。

## 2026-09-28 移除 hms/nrs 切换别名，roam switch 成为唯一切换入口（home/common.nix + 全仓引用清理，Fedora 44 / WSL2 standalone，本机）

前置：删除门槛由两条实机验证闭合——roam switch 的 standalone 分支（本机 2026-09-27/28 两次激活）与 NixOS 分支（NixOS-WSL 26.11 实机真 rc=0，含系统级安装位首覆，见上一条记录）。`hms` 为 standalone-only（NixOS 从未注入）、`nrs` 为 NixOS-only，替代命令串逐字一致，别名此时只剩肌肉记忆短写价值。

改动：`home/common.nix` 删除 `hms` 函数（整个属性集级 `isStandalone` 门控块随 `initExtra` 消失）、`nrs` 别名分支与 `hmTarget` let 绑定，函数头收回不再使用的 `username`/`isStandalone` 参数；「显式空串 vs 未设置 initExtra 生成不同 bashrc」的门控教训以注释存档（判断标准一节本就有）。外围引用同步：`packages/roam.sh` 自注释、`flake.nix`、`bootstrap/darwin.sh` 完成提示、`hosts/_template`、`hosts/wsl`、`profiles/nixos-base.nix`、README 六处（L23 带日期历史记录按惯例不动）、AGENTS.md 别名段重写 + 七处散点。过程教训：Edit 重写时凭记忆复打了未删除的相邻行，丢了 distrobox 五行别名末尾的分号（Nix 属性绑定间缺分隔符）——`nix-instantiate --parse` 当场拦截，「解析编辑过的文件」这道闸的即战果。

验证（本机 Fedora 44 / WSL2 standalone x86_64）：编辑文件全过 parse / `bash -n`；五输出求值全过（`roam check` 缺省 + 显式 wsl / nixos / aarch64-linux / aarch64-darwin）；activationPackage 构建（真 rc=0，含 roam.sh 注释更新后的新 roam.drv 过 ShellCheck 门）+ `roam switch` 激活（真 rc=0）；激活后交互 bash 中 `type hms` / `type nrs` 均未定义、生成 bashrc 无残留，`ll`/`archbox` 等存留别名与 `~/.nix-profile/bin/roam` 正常。

未验证：NixOS 侧（桌面/WSL）bashrc 里 `nrs` 的消失需该侧下次 `roam switch` 后生效——本改动已进其闭包（求值通过），激活留给用户下次切换；macOS 侧 `hms` 同理（darwin 分支本就桩级）。

## 2026-09-28 roam switch NixOS 分支（nh 路径）实机首跑通过（packages/roam.sh，NixOS-WSL 26.11 x86_64，本机 wsl）

复验：4e7a8af 落地时记「未验证：NixOS 分支（nh 路径与 WSL 补救提示触发）」——当时本机跑在 Fedora WSL standalone；今日本机为 NixOS-WSL 26.11（hostname `wsl` → `.#wsl` 输出），补上该分支实机首跑，并首次实机覆盖 NixOS 侧安装位（`profiles/cli.nix` → systemPackages → `/run/current-system/sw/bin/roam`）。本机存在多个 WSL 发行版，验证环境以本条为准。

验证（检出 3a614b4 干净树，用户 xuqihao 非 root）：前置健康——`systemctl is-system-running` = running、`user@1000.service` active（95ca45b linger 生效）、无 failed 单元；`roam info` 只读探测逐项正确（NixOS 26.11 / WSL=是 / x86_64 / 用户守卫通过 meta.json xuqihao / switch 目标 `nh os switch --diff always .` → `nixosConfigurations.wsl`）；实跑 `roam switch` 真 rc=0（`cmd; echo $?` 直取，不经管道）——nh 构建缓存命中（4s），nvd 差异 2108→2108 路径零变更（工作树与当前世代同源，符合预期），激活 + bootloader 登记，`system` profile 指向本次构建的 as55pfmzz… 世代（`system -> system-11-link`，链接 mtime 与运行时刻一致；同路径重建不新增世代号）；全程无 stc exit 4。

未验证：WSL 补救提示分支（仅 nh 失败时打印，成功路径不经过）；`roam switch` 额外参数透传未另测（命令串与 nrs 逐字一致已在 4e7a8af 记录）。

## 2026-09-28 roam update 支持选择输入（packages/roam.sh，Fedora 44 / WSL2 standalone，本机）

改动：`roam update` 升级为可选输入——缺省交互：从 flake.lock（jq 读 `nodes.root.inputs`，附当前 rev 短哈希与锁定日期）列出顶层输入，回车（或非交互 EOF / 无 jq / 无 flake.lock）=全部（默认全选），编号与名称可混用、逗号空格均可分隔，经白名单校验后 `nix flake update <输入>...` 只更新选中项；显式输入名（可多个）跳过交互；`--all` 跳过选择直接全量，与输入名互斥。AGENTS.md / README 同步。

事故与修复（同日）：首版 3 处刻意词切分未加 shellcheck 白名单注解 → writeShellApplication 的 ShellCheck 门报 SC2086，且 ShellCheck 0.11.0 在打印含中文的告警源码行时自身崩溃（`commitBuffer: cannot encode '\26411'`，无 locale 的构建环境所致）；更糟的是当时以 `cmd | tail` 取输出，把真实 rc 掩盖成 0，误判构建/激活成功，随后用安装位置仍是旧版的 roam 验证时它跑成旧逻辑，把真实仓库 flake.lock 意外全量更新——已 `git checkout flake.lock` 恢复（工作树仅剩本次改动文件）。教训入库：**writeShellApplication 脚本改动先以 `nix shell nixpkgs#shellcheck` 直查到零告警再进构建；验证命令的 rc 不得经管道取**（`cmd | tail; echo $?` 拿到的是 tail 的 rc，本日两次误判同源）。

验证（本机 Fedora 44 / WSL2 standalone x86_64）：/tmp 完整副本实测——显式输入名只动该节点（jq 前后比对其余输入 rev 不变）；名称、编号、混合多选（`4, nixvim` → `nixpkgs nixvim`）均正确解析；回车=全部（4 输入 Updated）；`--all` 与无效输入（`bogus`/`x`）正确拒绝并列出可用名。修复后 `nix shell nixpkgs#shellcheck` 零告警、`bash -n` 通过；activationPackage 重建（真 rc=0，新 roam.drv 过 ShellCheck 门）；`roam switch` 激活（真 rc=0，`~/.nix-profile/bin/roam` 换新 store 路径）；安装后二进制实测：菜单渲染正确（六输入带 rev/日期）、无效输入拒绝（真 rc=1）、flake.lock 未被改动。

未验证：安装后二进制的成功更新路径未在真实仓库跑（会动真锁文件）；同一脚本文本已在 /tmp 副本以 `bash packages/roam.sh` 全覆盖，包装差异仅 PATH。NixOS 分支（nh 路径）仍无实机；darwin 桩级。

## 2026-09-27 roam 统一 CLI（packages/roam.{nix,sh} + packages/cli-dev.nix，Fedora 44 / WSL2 standalone，本机）

改动：新增仓库自有统一 CLI `roam`——`packages/roam.sh`（脚本本体，macOS Bash 3.2 兼容）经 `packages/roam.nix`（writeShellApplication，构建期 bash -n + ShellCheck 门）打包，挂入 `packages/cli-dev.nix` 共享列表进入全部四个安装点。子命令按 `/etc/NIXOS` 探测分发（与 bootstrap/bootstrap.sh 同款约定，入口级重复系本仓库刻意允许）：`switch`（NixOS → `nh os switch --diff always .`，命令串与 nrs 逐字一致，WSL 下失败打印 stc-exit-4 补救提示；standalone → hms 同款逻辑：按求值平台选系统名输出 + meta.json 用户守卫）；`gc` 原样透传 `bootstrap/gc.sh`；`check [--build] [目标]` 复现 CI 两层验证（默认 `nix eval --raw …drvPath`，`--build` 时 `nix build --no-link`；目标可显式 nixos / wsl / x86_64-linux / aarch64-linux / aarch64-darwin，缺省为当前宿主）；`update`（`nix flake update` + flake.lock 差异摘要，不提交不切换）；`info` 只读打印探测结论。不带 runtimeInputs（闭包零新增依赖；nh / home-manager 缺失由脚本按子命令检测并给出出处指引）。AGENTS.md（别名段 + 目录树）与 README「更新与验证」段同步。

验证（本机 Fedora 44 / WSL2 standalone x86_64，用户 xuqihao）：脚本层 help / info（检出内外）/ 非检出守卫拒绝 / 未知目标拒绝全部实测；五输出求值通过（`roam check` 缺省 + 显式 wsl / nixos / aarch64-linux / aarch64-darwin，跨核对）；`roam check --build` 构建 standalone activationPackage 通过（roam.drv 过 ShellCheck 门，home-manager-path buildEnv 无名字冲突）；`roam gc --dry-run` 透传（gc.sh 自行识别出 Fedora WSL standalone 环境）；`roam update` 在 /tmp 完整副本端到端跑通（nixpkgs 双通道 lock 各升一版、12 行 diff 摘要、手动提交提醒，真 flake.lock 未动）；`roam switch` 实机激活 exit 0，`~/.nix-profile/bin/roam` 安装后 info 输出正常。

未验证：NixOS 分支（nh 路径与 WSL 补救提示触发）——本机无 NixOS，命令串仅与 nrs 逐字比对；darwin 分支（arm64 校验、Bash 3.2 直跑）桩级；aarch64 输出仅求值（与 CI 同界）；NixOS 桌面/WSL 侧安装位（经 profiles/cli.nix / modules/desktop/core.nix 进 systemPackages）未实机激活。



改动：Status 段 Public IP Address 之后新增 Location 行（`command` 模块），展示公网 IP 的地理定位。端点经本机（北京联通）实测筛选：`myip.ipip.net/json` 为主（HTTPS、中文地名、~0.13s），`ipwho.is` / `ipinfo.io/json` 依次回退（HTTPS、country/region/city 字段同名，jq 表达式复用）；淘汰端点——ip-api.com 明文 HTTP 3s 超时（复证 fastfetch.nix 既有弃用理由）、百度 qifu 404、ipapi.co 403、useragentinfo 空、vore.top 后端故障。关键语义：`jq -re` 在空输入（curl 失败）/无输出时退出 4，`||` 回退得以触发——sh 管道无 pipefail，不能只靠 `curl -f`；ipip 侧 `.data.location` 剔除空串后为空则输出 null（同因触发回退）。依赖 curl + jq，两者均在共享 `packages/cli-dev.nix`（curl:90、jq:69），四个安装位覆盖。

验证（本机）：`nix-instantiate --parse` 通过；standalone `x86_64-linux` activationPackage 构建通过（仅 HM 生成链重建，余走缓存）；用 store 内新 config.jsonc 实跑 fastfetch，Location 行渲染「中国 北京 北京 联通」；回退路径以伪造失效首端点实测落到 ipwho.is 输出；desktop/wsl toplevel 求值通过（HM 共享模块进两闭包，drvPath 如期移动）。

未验证：本机 `hms` 激活（用户步骤）；aarch64-linux / aarch64-darwin 构建（共享同一 HM 模块，无平台分支，jq/curl 两目标皆有）；NixOS 实机上的渲染（jq 走 systemPackages 的 secure_path 内路径，fastfetch 由用户 shell 调用，PATH 无虞）。

修正（同日，b2d3320 后用户反馈「没对齐」）：首版 Location 行的 `keyIcon` 经 hexdump 复核是**空字符串**（`22 22`，写入时图标字符在透传中丢失），`{icon}` 渲染为空 → 标签格比各行窄一列、整行错位。改用占位符 + `printf '\U000f034e'` 注入 `md-map_marker`（U+F034E，UTF-8 `f3 b0 8d 8e`，与现役 U+F0A79 同 MD 区段族）并 hexdump 校验字节后，重建重渲——各行标签格结构逐字节同构（`│ ` + 4 字节图标 + 2 空格 + 22 宽名称 + `│`），对齐恢复。教训入库：**Nix 文件里的 Nerd Font 图标必须 hexdump 验字节**，渲染缺失不可依赖文本透传；bash `printf '\uXXXX'` 只吃 4 位十六进制，5 位码点须用 `\U000xxxxx`。



起因：考证 AGENTS.md「China mirrors」段对 `vimPlugins.rainbow-delimiters-nvim` 的论断，发现两处与当前 lock 不符：① 许可——旧记录为 `meta.license = unfree`，今在两个锁定 nixpkgs rev（unstable `4975466`、nixvim 自带的 `cf9d2fb`）上 `nix eval` 实测均为 Apache-2.0（free=true；nixpkgs overrides.nix 显式 `license = lib.licenses.asl20`；`meta.hydraPlatforms = [ ]` 标记仍在）；② 缓存可得性——对本机闭包内的精确路径 `/nix/store/2n5q…-vimplugin-rainbow-delimiters.nvim-0.12.0` 用 `nix path-info --store` 实测，cache.nixos.org 与 NJU 镜像均命中（205.1 KiB 可替换），nix-community.cachix.org 亦命中。结论：当前 lock 上构建 nixvim 不再需要现抓 gitlab，cachix 由「必需」降级为「保险」——但 hydraPlatforms 标记仍在，lock 更新换出新派生路径时「新路径未被任何缓存收录 + gitlab 不可达」的组合可能复发，故缓存与公钥（meta.json）原样保留。

改动（纯文档/注释，无求值语义变化）：AGENTS.md「China mirrors」段、README.md 注意事项缓存条、`home/nix-cn.nix` 与 `modules/fix-network.nix` 注释、三个 bootstrap 脚本的 cachix 注释——口径从「unfree 包官方不构建」改为「hydraPlatforms = [ ] 路径 + 2026-09-27 复测结论」。

验证：`nix-instantiate --parse` 通过（两个 .nix）；`bash -n` 通过（三个脚本）；全仓 `rg rainbow-delimiters` 复核无 unfree 归因残留；`git diff --check` 干净。未重建/未激活——纯注释改动不参与求值，五个输出的求值结果与 drvPath 不受影响。

## 2026-09-26 gnome-extension-manager 归位 desktop-managers + AGENTS.md texlive 修正（desktop 侧模块 + 文档，Fedora 44 / WSL2 standalone，本机）

改动：① `gnome-extension-manager` 自 `modules/desktop/session.nix` 移至 `modules/desktop/desktop-managers.nix`（GNOME 软件段，与 gnomeExtensions.\* 同居，仍 pkgs-stable 同实例）——该工具管理 GNOME Shell 扩展，lite 档不 import desktop-managers（无 GNOME Shell），留在 session.nix 属闲置；全量桌面包集合不变，lite 实际减此一包。② 修正 d8d1ec3 的 AGENTS.md 遗留 stale 描述：dev.nix bullet 删去 "texlive scheme-full"（实际已在 office.nix），office.nix bullet 补记 texlive 及「lite 含 office 档故仍携带 TeX」。

验证（本机 eval-only，未构建/激活）：求值本身解析了两个被改模块。编辑前后对比——desktop `environment.systemPackages` 长度 635→635、gnome-extension-manager 计数 1→1（改由 desktop-managers.nix 提供）；nixos toplevel drvPath qn3r7rfw… → vi9gysi2…（如期移动，列表拼接顺序变化，与 4342a57 同性质）；wsl toplevel drvPath nfblrivv9… 逐字节不变（桌面模块不进 WSL 闭包）。lite 无 flake 输出、未直接求值：其 import 列表为 profiles/desktop.nix 的严格子集，全部模块已被本次 desktop 求值覆盖。

未验证：desktop/lite toplevel 构建（CI 亦仅 eval）；desktop 实机激活；lite 闭包实际少一包的磁盘收益（数 MB 级，可忽略）。

## 2026-09-26 AGENTS.md 补记 linger，对齐 95ca45b（docs-only，Fedora 44 / WSL2 standalone，本机）

纯文档：95ca45b 引入 `users.users.<username>.linger = true` 时未同步 AGENTS.md——NixOS-WSL 段的 stc-exit-4 记载补上第二个来源（WSL boot 无登录会话 → user@1000 不自启 → `/run/user/1000/bus` 缺失 → stc 用户单元重载失败）及其根治（声明式 linger）与放置理由（桌面机登录即起用户管理器，故留在 hosts/wsl）。无 Nix 改动，无需重建；`git diff --check` 干净。

## 2026-09-26 wsl 重开复验：进 gen 9、user@1000 自启、冷启动 nrs exit 0（NixOS-WSL 26.11，本机 wsl）

无代码改动；对上两条（autovt mask + 声明式 linger）的 `wsl --shutdown` 重开终验，闭环其「未验证」清单。

验证（实机，fresh boot 11:45）：`/run/booted-system` = `/run/current-system` = 0dw0z7a5…（26.11.20260923.4975466，gen 9）——**跨 WSL 重开持久确认**，未回退旧代；`user@1000.service` 开机自启（linger 标记生效）、`/run/user/1000/bus` 随 boot 就绪、`Linger=yes`；HM 服务 active、零失败单元；冷启动直接 `nh os switch --diff always .`（= nrs，无任何手动前置）**exit 0**，「激活 → bootloader」全链通过（闭包相同未建新代，属预期）。至此 wsl 主机 nrs 三层根因（autovt@tty1 失败单元、user@1000 不自启、nh 失败即不建世代）全部闭环。

未验证：desktop 输出构建与激活；CI 在本批提交上的运行。

## 2026-09-26 wsl：user@1000 声明式 linger，nrs 前置条件根治（NixOS-WSL 26.11，本机 wsl）

改动：`hosts/wsl/default.nix` 增 `users.users.${username}.linger = true;`（承上条遗留：WSL boot 无登录会话，user@1000 不自启 → `/run/user/1000/bus` 缺失 → stc 用户单元重载失败 exit 4 → nh 不建世代）。选项为 nixpkgs 原生声明式 linger（`users-groups.nix`，即 `loginctl enable-linger` 的等价物，activation 时落 `/var/lib/systemd/linger/<user>` 标记文件）。放置于 hosts/wsl 而非 nixos-base：桌面机经显示管理器登录即起用户管理器，无此依赖。

验证（实机）：解析通过；`config.users.users.xuqihao.linger` 求值 true；toplevel drvPath hjp8kpn9… → nfblrivv9…（如期移动）；`nh os switch --diff always .`（= nrs，user@1000 由上条手动拉起后在跑）**exit 0**，全链「激活 → bootloader」走完，**gen 9 建成**（system → system-9-link → 0dw0z7a5…，含本改动）；激活即生效：`loginctl show-user xuqihao -p Linger` = yes，标记文件 `/var/lib/systemd/linger/xuqihao`（02:35，activation 所建）；零失败单元。自此后每次 WSL boot：logind 见 linger 标记 → user@1000 常驻 → bus 就绪 → stc 干净 → nrs 恒建世代。

未验证：`wsl --shutdown` 重开后 user@1000 自启 + 实机进 gen 9（Windows 侧动作，机制上 linger 标记由 logind 开机消费，风险低）；linger 常驻的用户级单元内存开销（单用户 WSL，预期可忽略）；desktop 侧不受影响（未改动其链路，求值面 wsl-only）；CI。

## 2026-09-26 wsl 实机复测 ea68434：mask 生效，补 user@1000 前置后 nrs exit 0、gen 8 落地（NixOS-WSL 26.11，本机 wsl）

无代码改动；对上一条（补 mask autovt@tty1）的实机复测，承接其「未验证」清单。

验证（实机，~/nix-roam，`nh os switch --diff always .`）：① **mask 生效**——`unit-autovt-tty1.service-disabled` 入闭包（+4 路径，nvd 1bfraah5…→cwcs4a2j…），`/etc/systemd/system/autovt@tty1.service` → disabled symlink，切换全程 `systemctl --failed` 零单元。② 但首次复测**仍 exit 4、仍不建世代**——stc 输出已无「units failed」尾巴，剩余唯一触发源为 user activation：本 boot（01:42 起）`user@1000.service` 从未启动（journal 零条目、Linger=no）、`/run/user/1000/bus` 缺失 → stc「reloading user units」dbus autolaunch 失败。9-19 fresh boot nrs exit 0 的差异条件即在于彼时 user@1000 在跑。stc 已是 Rust 重写（`.switch-to-configuration-wrapped`，符号 `switch_to_configuration`），退出码不可读源，「user activation 失败 → exit 4」为行为实证（无失败单元 + 仅此警告 = 4）。③ `sudo systemctl start user@1000.service` 后 `/run/user/1000/bus` 立现、用户管理器 running 零失败 → nrs 重跑 **exit 0**，本机首次走完「Activating configuration → Adding configuration to bootloader」全链——**gen 8 建成**（`system → system-8-link → cwcs4a2j…`，26.11.20260923.4975466 含 mask），跨 `wsl --shutdown` 持久自此恢复（shim 从 profile 引导）。HM 服务 active；booted-system 仍指旧代属正常（下次 WSL 重启加载 gen 8）。

遗留（新边界）：`user@1000` 在 WSL boot 时不保证启动（本 boot 未起、9-19 起了，疑与会话建立方式有关）；未起时 nrs 又将 exit 4 于 user-reload 且不建世代（运行时激活仍成功）。可选根治：`sudo loginctl enable-linger xuqihao`（机器态 `/var/lib/systemd/linger/`，不入库），或跑 nrs 前确保用户管理器在跑（`sudo systemctl start user@1000`）。未验证：`wsl --shutdown` 重开后实机进 gen 8（Windows 侧动作）；linger 方案；CI。

## 2026-09-26 wsl：补 mask autovt@tty1，根治 nrs 不建系统世代（Fedora 44 / WSL2 standalone，本机）

改动：`hosts/wsl/default.nix` 在既有 `getty@tty1.service` mask（9-18，57af69e）之外补 `systemd.units."autovt@tty1.service".enable = false`。承接上条根因链：9-26 事故唯一失败单元 `autovt@tty1.service` 与 `getty@tty1.service` 是同一模板（`getty@.service`，`autovt@.service` 为其别名）的**不同实例名**，mask 互不覆盖——9-18 只 mask 了前者，故未防住。`enable = false` 语义对照所锁 nixpkgs（26.11.20260923.4975466）源码核验：`nixos/lib/systemd-lib.nix` 对 disabled 单元生成 `…-disabled` derivation（内容 `ln -s /dev/null`；选项文档原话即 "prevent specific template instances … from being started"），`generateUnits` 将其装入 /etc/systemd/system——该目录整体生成，`environment.etc` 逐条探针查不到 tty 条目属正常。mask 后单元无法进入 failed 态 → stc 不再 exit 4 → nh（nrs）得以走到「设 profile 建世代」一步。

验证（本机 Fedora 44 / WSL2 / standalone x86_64，纯求值）：两单元 `enable` 均为 false，unit derivation 名分别为 `unit-getty-tty1.service-disabled` / `unit-autovt-tty1.service-disabled`（即 /dev/null mask 形态）；wsl toplevel drvPath 9xrn8rvx… → hjp8kpn9…（如期移动，求值通过）；`grep -rn hosts/wsl flake.nix profiles modules home` 证实该文件仅 `.#wsl` 输出可达，standalone x86_64 activationPackage 求值正常（7wqs57fs…，求值路径不经过该文件）。

未验证：wsl 实机激活——须在 wsl 发行版内 `sudo nixos-rebuild switch --flake .#wsl`，同一条命令兼收止血（nixos-rebuild 先设 profile 后 stc，exit 4 不阻碍落世代）与根治（mask 随新世代进系统）；此后 `nrs` 是否恢复建世代、以及跨 `wsl --shutdown` 持久（建议重启前后各跑一次 nrs，核对 `/nix/var/nix/profiles/system` 是否推进）；system-units 目录实机构建产物（本轮以 derivation 名 + 源码推定，未构建）；CI。

## 2026-09-26 wsl 实机激活 11b9c69..d8d1ec3 一批 + 发现 nh 不建系统世代（NixOS-WSL 26.11，本机 wsl）

无代码改动；对近期一批提交（meta.json 单源、桌面求值修复、应用按档拆分、automation 下沉、desktop-lite——即 git 11b9c69..d8d1ec3，连同此前 c2e40c3 的 flake.lock 前滚）在 wsl 主机的首次实机激活。以 xuqihao 在 ~/nix-roam 运行 `nh os switch --diff always .`（= `nrs` 别名的实际命令；sudo 免密缓存）。

验证（实机）：构建 11 个派生全走缓存约 47s；nvd 代际 diff 正常（2101→2106 路径、15.9 GiB 持平、+57.8 MiB）；`/run/current-system` 5jr4dsnd…（26.11.20260911.eaad089）→ 1bfraah5…（26.11.20260923.4975466）；`home-manager-xuqihao.service` 重启成功（Result=success / exit 0）——与 9-19、9-24 两次 `user@1000` cgroup 故障不同，本轮用户管理器正常。7d8fdf8 的 WSL 自动维护首次落地：`nix-gc.timer`（OnCalendar=weekly + Persistent=true）、`nix-optimise.timer`（daily + Persistent=true）、`clean-user-generations.timer`（weekly）三新单元启动并排程（周任务次触发 2026-09-28 00:00）。

发现一（exit 4 成因，第三次但与前两现不同）：stc 返回 4（成功带失败单元），唯一失败单元 `autovt@tty1.service`——disabled 的模板实例在切换中被拉起，agetty `--keep-baud tty1` 即被 SIGHUP 杀（start-limit-hit；本 boot 此前无运行记录），系 WSL 无真实 tty1 的固有现象，与仓库改动无关；另有用户单元重载的 dbus `$DISPLAY` 警告（非图形 WSL 会话固有，HM 系统级激活不受影响）。无需 `wsl --shutdown`。

发现二（重要——nh 的 switch 流程与世代语义，9-19 首验未暴露）：本次 nh **未创建系统 profile 世代**——`/nix/var/nix/profiles/system` 仍 `system-7-link`（5jr4dsnd…，9-19 建），无 system-8-link。取证（nh-unwrapped 4.4.2 二进制字符串，`tr` 切串提取；源码与 crate 源均不在 store，GitHub 不可达）：nh 的 switch 流程为「① `switch-to-configuration test` 激活 → ② Setting NixOS profile（`--profile /nix/var/nix/profiles/system` 建世代）→ ③ Bootloader activation」，错误标签 "Activation (test)" 即第①步；二进制内无 WSL 特判（无 wsl/microsoft/osrelease 串），test 是 switch 的固有分解而非 WSL 降级。①因 autovt@tty1 exit 4 中止 → ②被跳过 → 世代未建。nh 自带诊断串 "Profile is out of sync with /run/current-system. This may happen if a previous switch failed during activation."——其自身失败路径本就会留下 profile（旧）与 current-system（新）失同步态，与本轮现场一致（下次跑 nh 应见此警告）。与 nixos-rebuild 顺序相反（`nix-env --set` 建世代**先于** stc），故 9-24 adopt 同为 exit 4 世代仍落盘。而 NixOS-WSL 引导链实证为 `/init → /sbin/init(systemd-shim) → /nix/var/nix/profiles/system/systemd`（shim 二进制内路径字符串）——**下次 `wsl --shutdown` 重开将回到 gen 7（20260911.eaad089），本次激活不跨 WSL 重启持久**。9-19 nrs exit 0「bootloader 步全过」未暴露此问题，因当时闭包与 gen 7 完全相同（不建新代不可分辨）。推论：autovt@tty1 不解决，nh 在本机每次都 exit 4、永不推进 profile——`nrs` 在此主机结构性失效（运行时激活本身每次成功）。补救：`sudo nixos-rebuild switch --flake .#wsl` 建 gen 8 落 profile（本记录时点尚未执行）；根治 autovt@tty1（如 NixOS 侧禁用该模板实例）后 nrs 方可恢复。

未验证：WSL 重开实测回退（基于 shim 路径 + profile 指针的推断，未实际重启）；`wsl --shutdown` 后重跑 nh 是否建代（同因未重启）；desktop 输出的构建与激活（桌面主机侧动作）；CI 在本批提交上的运行。

## 2026-09-26 桌面分级阶段 2：desktop-lite profile、会话栈抽出与 texlive 归位（Fedora 44 / WSL2 standalone，本机）

改动（lite 边界为用户决策：保留 dev+office+flatpak+browsers+agents，砍除 media/proxy/gaming/virtualization/mnt 与 GNOME/Plasma 备用 DE）：texlive scheme-full 自 dev.nix 归位 office.nix（排版属办公域）；profiles/desktop.nix 的会话栈（GDM/PipeWire/打印/图形/askpass）抽出为 modules/desktop/session.nix 供全量与 lite 共享；新建 profiles/desktop-lite.nix（= nixos-base + session + niri + locale-zh + core + flatpak + browsers + dev + office + agents；mysql 随 dev、texlive 随 office 一并带入 lite）。

验证（本机 Fedora 44 / WSL2 / standalone x86_64）：desktop-lite 组合经 flake 内临时 `_litecheck` 输出（带 fileSystems/bootloader 硬件桩；验证后已还原 flake.nix，不入提交）纯求值通过（vsq3r5b…），12 个档位开关核对全对——gdm/pipewire/mysql/hermes-agent/flatpak/nix.gc = true，steam/clash-verge/docker/gnome/plasma6/waydroid = false；texlive 挪档 + session 抽出后 desktop 的 635 个包路径与拆分基线零增零减，桌面求值通过（qn3r7rf…）；wsl drvPath 与 automation 下沉后的值一致（9xrn8rv…，本轮零影响）；standalone 三输出与最初基线仍逐字节一致；`git diff --check` 干净。

未验证：desktop-lite 无真实主机（仓库刻意不为其添加 flake 输出——第二台主机立项时按模板 + `--target` 脚手架接线，hardware-configuration 与 variables.nix 届时为真实值）；任何目标的构建与激活；CI 在本批提交上的运行。

## 2026-09-26 桌面应用清单按档拆分 + automation 下沉 nixos-base（Fedora 44 / WSL2 standalone，本机）

改动（4342a57）：`programs.nix`（274 行）按档拆为 `modules/desktop/{core,browsers,dev,media,office,proxy,gaming}.nix` —— core 只收开源软件（firefox/chromium 留守，chrome/edge/servo 移 browsers；earlyoom/nix-ld 与 cli-dev 挂载随 core），dev 收编辑器/clang/texlive/distrobox 并接管 mysql（用户决策：mysql 是 dev 的），office 收办公 + 中文软件 + wechat overlay（overlay 随档，不 import 即整体不生效），gaming 收 steam 并归位 `hardware.graphics.enable32Bit`（profiles/desktop.nix 只留 enable）；`services.nix` 解散（earlyoom→core、mysql→dev、rustdesk 注释块→core）；`flatpak-linyaps.nix` 拆为 flatpak.nix（商店 + SJTU 镜像）与 desktop-managers.nix（GNOME/Plasma 备用 DE + 扩展 + dconf）。`profiles/desktop.nix` 改为按档 import 全集，hosts/nixos 行为不变；cli-dev/nixos-base/standalone-linux 中指向 programs.nix / flatpak-linyaps 的注释同步更新。

改动（本条目第二提交）：`automation.nix`（nix.gc / nix.optimise / clean-user-generations）下沉 `profiles/nixos-base.nix` —— 用户决策通过；WSL 从此启用自动 GC（每周 `--delete-older-than 2w` + 每日 optimise + 每周用户世代清理，WSL 下次 switch 首次落地），桌面为同值迁移。

验证（本机 Fedora 44 / WSL2 / standalone x86_64）：拆分为纯重组——desktop 的 `environment.systemPackages` 635 个 outPath 前后完全一致（按 outPath 排序对比，零增零减）；earlyoom / mysql / steam / clash-verge / nix-ld / flatpak / gnome / plasma / gc.automatic 九选项保真 true；wsl toplevel 与三个 standalone activationPackage 的 drvPath 拆分前后逐字节一致；desktop drvPath 因包列表跨模块拼接顺序变化而移动（0bslg44s… ← xgd7r8cd…，属预期：system-path buildEnv 对输入顺序敏感）。automation 下沉后：desktop drvPath 与拆分后一致（同值迁移证明），wsl drvPath 如期变化（9xrn8rvx…）且 `nix.gc.automatic` / `nix.optimise.automatic` / `clean-user-generations.enable` 均 true，standalone 三输出不变；`git diff --check` 干净。

未验证：desktop/wsl toplevel 构建（CI 对 NixOS toplevel 仅求值，闭包含 unfree 大件）；实机 `nrs` / wsl switch 激活（主机侧动作）；lite profile（阶段 2，第二台桌面主机立项时再定边界）；CI 在本批提交上的运行。

## 2026-09-26 桌面求值修复：dms-shell 失效选项 + electron-41.9.1 允许条目（Fedora 44 / WSL2 standalone，本机）

起因：c2e40c3「update flake」后 `.#nixos` 求值失败（CI eval 层同罪）。两层问题被 dms-shell 断言错误掩盖，逐层剥开：① `modules/desktop/niri.nix` 的 `programs.dms-shell.{enableDynamicTheming,enableAudioWavelength,enableVPN}` 已被上游移除（matugen/cava 入默认环境、网络后端运行时自检）；② 断言修掉后露出 insecure 拒绝——桌面闭包经 flake.nix `nixpkgsConfig` 管辖的实例引用 electron-41.9.1（EOL）。

改动：niri.nix 删三个失效选项（沿 enableSystemMonitoring 先例留注释）；flake.nix `nixpkgsConfig` 增 `permittedInsecurePackages = [ "electron-41.9.1" ]`。`profiles/nixos-base.nix` 经探针验证无需改动——系统 unstable 实例仍只引用 electron-40.10.5（原条目原样保留；本轮曾误将其替换为 41.9.1 导致旧版消费者被拒，已回退）。两处探针：移除 flake.nix 条目 → 桌面求值失败（条目必需）；nixos-base 只留 40.10.5 → 桌面求值通过（无需 41.9.1）。

验证（本机 Fedora 44 / WSL2 / standalone）：`.#nixos` toplevel 求值通过（xgd7r8cd…，26.11.20260923.4975466）；wsl toplevel 与三个 standalone activationPackage 的 drvPath 与同日重构基线仍逐字节一致（nixpkgsConfig 允许列表为「允许」语义，standalone 不引用 electron 不受影响）；`git diff --check` 干净。

未验证：桌面 toplevel 构建（闭包含 unfree 大件，历史上 QQ 下载失败中止过，CI 对 NixOS toplevel 也仅求值）；实机 `nrs` 激活（桌面主机侧动作）；electron-41.9.1 的具体引用包归属（求值错误只给实例不给包名，未逐包归因）；CI 在本批提交上的运行。

## 2026-09-26 镜像/公钥收敛 meta.json 单源 + locale-zh 反向 import 清理（Fedora 44 / WSL2 standalone，本机）

改动：`meta.json` 从单点 username 扩展为三字段——新增 `substituters`（空格分隔六项：NJU→TUNA→USTC→SJTU→cache.nixos.org→cachix 末位，顺序沿用 nix-cn.nix 旧值）与 `nixCommunityCachixKey`（mB9F… 公钥）。`home/nix-cn.nix` 的 substituters 改 `lib.splitString " "` 读同文件，`modules/fix-network.nix` 的 trusted-public-keys 改读同文件；`bootstrap/{linux,darwin}.sh` 与 `bootstrap/nixos.sh` 的两条硬编码变量改为 sed 提取（与 username 同款模式）+ fail-loud 守卫，`nixos.sh` 补 `SCRIPT_REPO` 自定位（其 1/7 步执行时 CLONE_DIR 尚未克隆）。三处手动追加的 `https://cache.nixos.org` 删除——顺带修复既有漂移：bootstrap 写出的用户级顺序原为「四镜像→cachix→官方」，与 nix-cn.nix 的「四镜像→官方→cachix」不一致，现统一为后者；daemon 侧 trusted-substituters 从此也列官方源（本就默认受信，重复无害）。幂等跳过检查（grep nix-community.cachix.org）未动。另删 `modules/desktop/locale-zh.nix` 对 `profiles/locale.nix` 的冗余反向 import（desktop 链路经 profiles/desktop.nix → nixos-base.nix 已传递导入同一文件，模块系统按路径去重，删除为纯清理）。

验证（本机 Fedora 44 / WSL2 / Determinate Nix 3.22.2，standalone x86_64）：改动前取基线——wsl toplevel 与三个 standalone activationPackage 的 drvPath、wsl 的 `nix.settings.substituters`/`trusted-public-keys`；桌面输出改动前后均因 `modules/desktop/niri.nix` 三个失效 dms-shell 选项（enableAudioWavelength / enableDynamicTheming / enableVPN，上游 nixpkgs 已移除该批选项，与本次改动无关，待另行修复）无法求值，失败选项集合前后一致。改动后：四个可求值输出 drvPath 与基线逐字节一致；两选项 JSON 与基线一致；`x86_64-linux` activationPackage 的 outPath 已在 store（同一 derivation 本机构建过，无需重建）；三脚本 `bash -n` 通过；与脚本同款的两条 sed 对新 meta.json 实测提取值逐字符正确（username 提取不受影响）；`git diff --check` 干净。

未验证：三个 bootstrap 未实机重跑（幂等重跑属用户侧动作，本轮边界为 bash -n + sed 提取实测 + 逐行核对）；新装机器上顺序统一的实际写入效果；darwin/aarch64 实机构建；桌面输出仍被上述无关失效选项挡住（修复后可补 drvPath 对比）；CI 在本批提交上的运行。

## 2026-09-24 单用户安装激活后 nix 不在 PATH（ArchLinux-WSL 首次 single 全程安装，本机 ArchLinux-WSL）

起因：ArchLinux-WSL（裸机、原本无 xuqihao 用户）经 bootstrap 建号 + `NIX_INSTALL_MODE=single` 七步全程完成安装并激活（当日 18:34–18:50，gen 1），激活本身成功，但此后任何新登录 shell 都找不到 `nix`。根因：单用户安装的 PATH 挂钩由官方安装器写进用户 dotfile（`~/.bash_profile` 尾行 source `~/.nix-profile/etc/profile.d/nix.sh`），而 HM 激活把 bash 登录链三件套（`.bash_profile`/`.profile`/`.bashrc`）整体替换为 store symlink，原文件轮转入 `.bash_profile.backup`/`.bashrc.bak-*`；HM 侧 `home.sessionPath`（common.nix）却不含 `~/.nix-profile/bin`。多用户安装不受影响（钩子在系统侧 `/etc/profile.d/nix-daemon.sh`，经 `/etc/profile` 恒先于用户 dotfile 加载）——single 模式特有缺口；bootstrap 运行全程无感，因为脚本会话继承的是安装时已 source 的旧 dotfile 环境。

改动：`home/standalone-linux.nix` 显式补 `home.sessionPath = [ "${homeDirectory}/.nix-profile/bin" ]`（listOf 合并与 common.nix 五条拼接；多用户机上与 nix-daemon.sh 注入重复无害；NixOS 模式不导入本文件不受影响，彼处无 `~/.nix-profile`）。`bootstrap/linux.sh` 7/7 之后新增 fail-loud 自检：`env -i` 干净环境起 `/bin/bash -lc` 验证 `command -v nix`，失败即报错退出并指向 sessionPath（zsh/fish 的 rc 追加段仅交互会话生效，注释中明确不在该检查范围）。

验证（本机 ArchLinux-WSL / WSL2 / 单用户 Nix 2.35.2，standalone `.#x86_64-linux`）：`bash -n` 与 `nix-instantiate --parse` 通过；`nix build --no-link .#homeConfigurations.x86_64-linux.activationPackage` 构建通过（闭包全缓存，仅重出 profile/activation/files/hm-putter/generation 五个派生）；`home-manager switch` 激活 gen 2（9va1j13…）exit 0；干净登录 shell（`env -i … /bin/bash -lc`）实测修复前复现 `NO-NIX-IN-PATH`、修复后 `nix`→`~/.nix-profile/bin/nix`（2.35.2）且 `home-manager` 同目录可用；交互登录 shell `type -t hms` = function（hms 定义在 `.bashrc` 交互守卫之后，非交互 shell 不可见属预期）；新 `hm-session-vars.sh` 的 `export PATH` 末位含 `~/.nix-profile/bin`；bootstrap 自检代码块原样抽出复跑 PASS。

未验证：aarch64-linux 输出（同模块，需 ARM 机）；自检在真实失败场景下的触发（仅正向复跑）；bootstrap 七步全程带新自检的重跑（本轮机器已装好，脚本幂等重跑属用户侧动作）；darwin 侧同类问题是否存在（macOS 安装器钩子在系统级 `/etc/zshrc`，理论不受影响，且 darwin.sh 从未实机运行）；CI 在本批提交上的运行。

## 2026-09-24 cachix 社区缓存补入缓存列表（Fedora 44 / WSL2 standalone，本机）

起因：`hms` 在本日 `update flake`（c2e40c3，15:28）后失败——`home/nixvim.nix` 启用的 `rainbow-delimiters` 要 `vimPlugins.rainbow-delimiters-nvim` v0.12.0，其源码 FOD 由 `fetchgit` 从 gitlab.com 取；本机网络下 `getent hosts gitlab.com` 只给被污染的 Cloudflare IPv6（2606:4700:90:…），`git ls-remote` 40s 无响应，构建退化为 reset + 两次 300s 超时后失败，级联 `vimplugin → neovim → nixvim → home-manager-path → home-manager-generation`。查因：该插件在 nixpkgs 中 `meta.license = unfree` → `meta.hydraPlatforms = [ ]`，官方 Hydra 不构建，源码与产物都不在 cache.nixos.org（实测该 FOD `/nix/store/cxyk83xx…-rainbow-delimiters.nvim` 在 cache.nixos.org 与 NJU/TUNA/USTC/SJTU 四个镜像全 404，而同一 store 随机取 3 个 `-source` FOD 均为 200；drv 的 `outputHash` 与社区缓存 narinfo 的 `NarHash: sha256:0zy93xwc…` 一致）。旁证：store 中已存在此前 substitute 来的 `2n5q…-vimplugin-rainbow-delimiters.nvim-0.12.0`，说明 flake 更新换掉 neovim/插件派生路径前并不需要现抓——本次是路径变化与上游不可达同时发生。另注：报错开头的 `options.json` 警告是求值期噪音（`nixosOptionsDoc` 把 nixpkgs 源码路径写进 JSON 字符串，string context 丢失），与本故障无关。

改动：`home/nix-cn.nix` 的 `substituters` 末位加 `https://nix-community.cachix.org`；`modules/fix-network.nix` 加 `nix.settings.trusted-public-keys = [ <cachix 公钥> ]`；`bootstrap/{linux,darwin,nixos}.sh` 的缓存变量追加该地址、新增 `CACHIX_PUBLIC_KEY`，以 `extra-trusted-public-keys` 写入（multi 写 daemon 的 `/etc/nix/nix.custom.conf`；linux 单用户写用户级 nix.conf 与 `NIX_CONFIG`；nixos.sh 另入 `NIX_CONFIG`）；三个脚本的幂等跳过标记由 NJU 改为 `nix-community.cachix.org`，使旧配置被重写一次而不是跳过；`AGENTS.md`/`README.md` 同步说明与手工补救命令。公钥刻意不进 `home/nix-cn.nix`：那会落到 standalone 用户 nix.conf，而 `trusted-public-keys` 对非受信用户（本机实测 `trusted-users = root`）是受限设置，每次连 daemon 都会打印 `ignoring the client-specified setting`。

验证（本机 Fedora 44 / WSL2 / Determinate Nix 3.22.2，standalone 目标 `.#x86_64-linux`）：① 公钥经 `nix store verify --store https://nix-community.cachix.org` 实测——`mB9F…` 判定通过、旧引用的 `LwCD…` 报 `path … is untrusted`，故取 `mB9F…`；② `nix config show` 实测 `extra-trusted-public-keys` 为追加语义（内置 cache.nixos.org-1 与安装器的 flakehub 各键均保留）；③ 用锁定的 nixpkgs 26.11 源码 `lib.nixosSystem` 对改后的 `modules/fix-network.nix` 做定向求值，得 `substituters = 四镜像 + cache.nixos.org + cachix`、`trusted-public-keys = cache.nixos.org-1 + cachix`（即 `nix.settings` 的 listOf 合并不会顶掉官方 key）；④ 三个脚本 `bash -n` 通过；把脚本中真实的 2/7（nixos.sh 为 1/7）代码块抽出桩测：multi 旧配置升级只写一次、重跑跳过、无重复行，linux 单用户分支在已有 `substituters` 时只补公钥、二次运行不重复，HM symlink 分支不落盘，nixos.sh 的 `NIX_CONFIG` 在带/不带 token 两种情况下按行正确拼接；⑤ `git diff --check` 干净。

未验证：`hms` 真实 substitute（需 root 先按 README 把 cachix 写进本机 `/etc/nix/nix.custom.conf`，属用户侧动作，本机 `/etc/nix` 未改动）；NixOS 桌面/WSL 与 darwin 目标的构建与激活；flake 五输出的完整求值/构建——本机 flake 输入（home-manager / nixvim tarball）不在 store 且 api.github.com 被污染，`nix eval`/`nix build` 均卡在取输入阶段，故上述③是对受影响模块的定向求值而非整 flake 求值；CI 在本批提交上的运行。

## 2026-09-24 bootstrap 派发 → nixos.sh adopt 实机首跑 + 幻影 cgroup 二现（NixOS-WSL 26.11，本机 wsl）

无代码改动；`bootstrap/bootstrap.sh`（派发器 → sudo 重 exec → `nixos.sh` adopt）在 NixOS-WSL 实机首跑——此前 install/adopt 两链路均未上过实机，派发器的 NixOS 分支亦为首次实跑。以 xuqihao 启动：派发器正确识别 `/etc/NIXOS` → nixos.sh；模式 adopt、目标 `.#wsl`（WSL 内核标记）、仓库 `/etc/nixos`；日志按设计落 root 侧 `/root/.local/state/nix-roam/nixos-20260924-155717.log`。

验证（实机，1–5/7）：1/7 镜像信任已配置跳过 ✓，且正确识别 `/etc/nix/nix.conf` 为 nix.settings 托管 symlink → 不追加 include、镜像经 `NIX_CONFIG` 生效 ✓；2/7 token 留空沿用旧值 ✓（stdin 交互、未入日志）；3/7 `/etc/nixos` 已是本仓库克隆 → 复用不重拉 ✓；4/7 `/etc/NIXOS` 读不出原系统版本（该文件无版本串）→ 按共享 26.05 继续 ✓（本机 flake 即 26.05，无偏差）；5/7 `nixos-rebuild switch → .#wsl` 构建并激活 gen 4（fm49i01…，与 gen 2 同闭包；gen 3 为 9-19 临时树）✓，`home-manager-xuqihao.service` 15:57:28 激活成功（系统级服务不走用户总线）。

发现一（宿主故障二现，非仓库回归）：stc exit 4——`reloading user units for xuqihao: Failed to open dbus connection (Unable to autolaunch a dbus-daemon without $DISPLAY)`。与 2026-09-19 首现同因：本 boot `user@1000.service` 全程未起、`/run/user/1000/bus` 缺失 → 仅用户单元重载一步失败，系统激活本身成功。恢复：Windows 侧 `wsl --shutdown` 重开 → `user@1000.service` 263ms Ready、用户级 NixOS activation 完成、`systemctl --user is-system-running` = running；fresh boot 直接加载 gen 4 用户单元，本轮未重跑 switch。两现间隔 5 天（kernel 6.6.114.1-microsoft-standard-WSL2 / systemd 261.2），再复现应追 WSL2 内核/systemd upstream。

发现二（脚本边界，待改进项）：`set -euo pipefail` 下 stc exit 4（成功带警告）直接中止脚本，6/7（adopt 场景本为跳过提示）与 7/7（收尾提醒）未执行；激活已成功故无功能损失，但收尾信息被吞——后续可考虑 5/7 对 exit 4 容忍（仅非 4 的非零才中止）。

未验证：install 链路（live ISO）仍无实机；adopt 的外来 `/etc/NIXOS`/`/etc/nixos` 备份分支与 stateVersion 不符确认分支（本机仓库即原生、版本一致未触发）；恢复后重跑 switch 的 exit 0（本轮以 fresh boot 替代，9-19 已单独验过）；CI 在本批提交上的运行。

## 2026-09-24 WSL 默认用户改为询问后写入 /etc/wsl.conf（Fedora 44 / WSL2 + ArchLinux-WSL 实机）

改动：`linux.sh` 守卫建号分支的 WSL 提示升级为询问（`[Y/n]` 默认 Y）：同意则把 `[user] default=<username>` 合并进 `/etc/wsl.conf`——保留既有段落与键、原文件带时间戳备份、写失败仅警告不中断安装；拒绝则保留原手动提示。合并逻辑为纯 bash 函数 `wsl_conf_merge()`（内建 + 正则，零外部依赖）：实测作者日常 Fedora WSL 未安装 gawk，`awk` 不能假设存在（`darwin.sh` 的 awk 保留——macOS 系统自带 BSD awk）。

验证：`wsl_conf_merge` 自脚本抽出单测 8/8 通过（文件不存在/空/仅 `[boot]`/已有 default 替换/裸 `[user]`/`[user]`+其他键/多段保留替换/幂等重入）；本机桩测 root+无 sudo 全链路（建号 y → wsl.conf 询问 n 跳过 → su 切换重跑 → 第二轮中止）通过，且本机真实 `/etc/wsl.conf` 未被触碰；**ArchLinux-WSL 实机**：建号 → 询问回车取默认 Y → 写入成功，合并后 `[boot] systemd=true` 原样保留、新增 `[user] default=xuqihao`，备份 `/etc/wsl.conf.bak-20260924-151406`（20 字节原文），随后 su 切换与 1/7 Nix 安装照常（30s 截停于下载中）。途中顺带实测「目标用户已存在」分支输出（含 su -l 提示）。两个环境层发现：① binfmt 的 WSLInterop 注册一度丢失致 `wsl.exe` 无法执行（有界截停互操作进程的副作用），`echo :WSLInterop:M::MZ::/init:PF > /proc/sys/fs/binfmt_misc/register` 恢复；② 此前「有界截停」实际未截住 su 之后的进程树（地下继续跑到 home-manager 步骤），清理时须按用户 `pkill`——本轮起已按此清理。

未验证：七步全程实机跑完；非 root+sudo 路径的 wsl.conf 写入（桩覆盖，写入前缀不同逻辑同构）；`wsl --shutdown` 重开后默认用户实际生效（需 Windows 侧操作）；CI 在本批提交上的运行。

## 2026-09-24 守卫建号支持 root 直跑与无 sudo 环境（Fedora 44 / WSL2 standalone Nix + ArchLinux-WSL 实机）

改动：`bootstrap/linux.sh` 0.7 守卫的提权判定从「非 root 且可 sudo」扩为「root 本身或非 root 可 sudo」；root 分支不加 sudo 前缀执行 `useradd/usermod/passwd`、仓库复制走 `cp -a + chown -R`、切换重跑以 `su --login <user> -c '<单串>'` 为主（`runuser --login -c` 兜底）、root 且无 sudo 二进制时预建 `/nix`（0755，属新用户）使重跑落入单用户安装；已存在目标用户的分支补 `su -l` 提示。起因：在 root-only、未装 sudo 的 ArchLinux-WSL 上，原判定在 `have sudo` 处失败，交互询问从未出现。

验证：**ArchLinux-WSL（root-only / 无 sudo / systemd 开启）实机全链路**——交互询问 → `useradd` 真实建号 → 无 sudo 说明 → `/nix` 预建 → 仓库复制属 xuqihao → WSL 提示 → `su -l` 切换成功 → 第二轮日志落在 `/home/xuqihao/.local/state/` → 模式判定 `single-user（systemd: yes，sudo: no）` → 官方安装器真实下载并安装 Nix 2.35.2 至预建 `/nix`，30s 超时截停（完整七步未跑完，属有界验证；passwd 用桩避免真实设密）。本机（Fedora 44）桩测回归：非 root 拒绝/同意两分支 + root+无 sudo（minbin 模拟）全链路均通过。过程中两个实测发现：① `runuser/su -- CMD ARGS` 多参数形式在 util-linux 上报 `cannot execute binary file`（Fedora/Arch 双现）→ 统一 `-c` 单串 + `printf %q`；② `runuser -c` 在该 Arch 的 logind 异常下挂死（其 PAM `session include system-login` 含 pam_systemd；`su` 为纯 pam_unix 不受影响）→ su 为主、runuser 兜底。Arch 侧终态：用户 xuqihao、`/home/xuqihao/nix-roam` 副本与空 `/nix`（属 xuqihao）保留供完整安装，半装的 store/profile 残留已清。

未验证：七步全程在实机一次跑完（截停于 1/7）；真实 `passwd` 交互（实机用桩）；root+有 sudo 的实机分支（仅桩覆盖）；`darwin.sh` root 路径与整条链路（macOS 必有 sudo，理论经 `sudo -v` 即通过，未实机）；CI 在本批提交上的运行。

## 2026-09-24 standalone 用户守卫改为可建号（Fedora 44 / WSL2 standalone Nix，本机）

改动：`bootstrap/linux.sh`/`darwin.sh` 的 0.7 目标用户守卫从「用户名不符即中止」升级：目标用户已存在 → 提示换登重跑（不动既有账号）；交互终端且可 sudo → 询问是否创建 meta.json 定义的系统用户并以它继续——linux 走 `useradd -m` + 交互 `passwd` + best-effort 加入 sudo/wheel 提权组，darwin 走 `sysadminctl -addUser … -admin -password prompt`；随后仓库 `cp -a` 到新用户家目录（失败回退当前副本只读使用），`exec sudo --login --user` 以新用户重跑本脚本（与 NixOS 侧 flake 直接 `users.users.<username>` 建号对齐）；拒绝/非交互/无 sudo 仍 fail-loud 中止并给 meta.json 指引。WSL 下打印 `/etc/wsl.conf` 默认用户设置提示但不自动写。

验证（桩测，本机）：`linux.sh` 分支实跑覆盖——非交互中止 ✓；交互拒绝（改 meta.json 指引）✓；交互同意全链路（useradd/usermod/passwd/getent 经 PATH shim 桩替，真实执行了提权组校验、`cp -a` 复制、WSL 提示、以新用户重跑**复制出的仓库副本**、第二轮守卫再触发）✓；复制失败回退原仓库重跑的兜底分支 ✓；目标用户已存在（root）提示换登 ✓。四脚本 `bash -n` 通过。桩测期间发现并修正的三处均为桩缺陷（sudo shim 漏过滤 `-v`、getent 桩的 passwd 行少 GECOS 字段、useradd 桩未建家目录），非脚本缺陷。

未验证：真实 `useradd`/`passwd`/提权组在实机的执行、以新建用户身份走完七步安装（本机登录名即 xuqihao，无法自然触发真实建号分支）；`darwin.sh` 整条链路含 `sysadminctl -addUser -password prompt` 语法（按官方文档核对，从未实机运行）；CI 在本批提交上的运行。

## 2026-09-24 standalone 输出改按系统名命名（Fedora 44 / WSL2 standalone Nix，本机）

改动：`homeConfigurations` 三个 standalone 输出由 `xuqihao` / `xuqihao-aarch64` / `xuqihao-darwin` 改名为 `x86_64-linux` / `aarch64-linux` / `aarch64-darwin`（输出名不再随用户名变化；`homeDirectory` 与模块内容不变）。联动：`home/common.nix` 的 `hmTarget`（`hms` 目标）改为系统名；`bootstrap/{bootstrap,linux,darwin}.sh` 默认 target 按架构取系统名，显式传参须与本机架构一致（新增 fail-loud 校验），目标用户守卫从「target 剥后缀还原用户名比对 `id -un`」改为「直接比对 meta.json 的 username」——顺带堵上此前「显式传自己的登录名即可绕过守卫、直到激活阶段才失败」的缺口；`bootstrap.sh` 不再为派发读 meta.json；CI `eval.yml` 输出名同步。

验证（本机求值/构建/激活）：五输出求值通过；两 NixOS toplevel drvPath 与改动前逐字节一致（`hms` 不注入 NixOS 侧），三个 standalone 输出 drvPath 如预期变化——构建 x86_64 activation 仅 4 个派生重建（bashrc→home-manager-files→generation 链），证明内容面只有 bashrc。本机激活 `.#x86_64-linux` 成功（gen 14，2026-09-24 00:42），新 bashrc 的 `hms` 指向 `.#x86_64-linux`；激活时 systemd 报 wslg-session.service degraded 为本机宿主既有问题，与本改动无关。另注：本机此前 profile 停在 2026-09-17 的 gen 13（仍含旧 hms 别名文本与 standalone 上早已门控排除的 `nrs='sudo nixos-rebuild'` 别名），本次激活一并追平。三脚本 `bash -n` 通过。

未验证：aarch64 / darwin 输出仅求值（无 ARM/macOS 实机）；darwin.sh 新目标校验与守卫文案未实跑（与 linux.sh 同构改法，经 bash -n + 逐段核对）；bootstrap 全链路未在已激活的本机重跑；CI 在本批提交上的运行。

## 2026-09-19 nrs/nh 实机首验 + WSL cgroup 用户管理器故障（NixOS-WSL 26.11，本机 wsl）

无代码改动；对 9d4d8e7（多机兼容性五连改）遗留未验项 `nrs` 的实机验证。本机当时代际：gen 7（2026-09-19 13:35，已含 nh 与新别名，由用户经 sudo nixos-rebuild 激活）。

验证：`bash -ic 'type nrs && nrs'` 实跑——别名解析 ✓、cwd 相对 `.` 解析 ✓、`--hostname` 默认匹配 `.#wsl` ✓、构建 1s 全缓存 ✓、**nvd 代际 diff 输出正确**（2101→2101 路径、15.9 GiB→15.9 GiB、DIFF 0 字节——同树切换的预期值）、nh 对失败的呈现清晰（结构化错误 vs nixos-rebuild 的裸串）。

发现（宿主故障，非仓库回归）：激活步 stc exit 4——`reloading user units for xuqihao: Failed to open dbus connection (Unable to autolaunch a dbus-daemon without $DISPLAY)`。A/B 对照：`sudo nixos-rebuild switch --flake .#wsl` **同样 exit 4、同样警告**，证明与 nh 无关。根因：本次 boot（13:34）起 `user@1000.service` 无法启动（`Failed to spawn executor: Device or resource busy`，同秒即败）；logind 建了 session c1 但从未尝试启动用户管理器；`/run/user/1000/bus` 不存在 → stc 用户单元重载失败。cgroup 现场确认幻影占用：`user.slice/user-1000.slice/user@1000.service` 下 `init.scope`/`session.slice` 的 `cgroup.procs` 为空、`cgroup.threads` 报 `0`、`cgroup.events` `populated=1` 永不落零、三者 `rmdir` 均 EBUSY（与 spawn 失败同 errno）；对照实验：`systemd-run --uid=1000 --slice=user-1000.slice` 可正常 spawn，问题特定于该单元的 cgroup 子树。上一 boot（9月16日，systemd[451]）用户管理器正常。影响面：本 boot `systemctl --user` 与 HM 用户单元全部不可用；系统其余正常（`is-system-running` running、gen 7 不变、无新代际——闭包相同未建 gen 8）。

未验证：~~exit 0 的完整 nh 切换~~——已补验（同日 13:57）：Windows 侧 `wsl --shutdown` 重开后 `user@1000.service` 正常启动（幻影 cgroup 未随 fresh boot 复现，单次观察），`nrs` 重跑 **exit 0**，激活 + bootloader 步骤全过、无警告，系统保持 `running`、gen 7 不变（闭包相同未建新代际）；过程中注意到 dirty Git tree 会令 nh 打印 `warning: Git tree ... is dirty`（本地未提交的文档改动所致，无害）。幻影 cgroup 是否为偶发仍待观察（复现则需追 WSL2 内核/systemd 261 upstream）。桌面输出未动。

## 2026-09-19 多机兼容性五连改（Fedora 44 / WSL2 standalone Nix，本机）

改动：借鉴 ZaneyOS 评审结论的五项：① per-host `hosts/<host>/variables.nix` 旋钮（`timeZone` 自 `profiles/nixos-base.nix` 迁出，flake 两个 nixosConfigurations 块以 `vars` specialArg 注入，接线点唯一）；② `profiles/hardware/` 休眠 GPU/VM profile 层（nvidia/amd/intel/vm-guest；nvidia 的 prime offload 由 `vars.gpuBusIDs` 条件启用，未提供时为纯 dGPU 配置）；③ `hosts/_template/` 主机模板 + `bootstrap/nixos.sh` 任意 `--target <主机名>` 脚手架（复制模板并替换 `__HOSTNAME__`，打印桌面/CLI 两种 flake 输出样例，人工粘贴后 grep 校验输出存在，不自动改 flake.nix；install 链路 `hosts/nixos/hardware-configuration.nix` 与 `.#nixos` 等硬编码泛化为 `${TARGET}`）；④ linux/darwin/nixos 三条链路全程时间戳日志（`${XDG_STATE_HOME:-$HOME/.local/state}/nix-roam/`）；⑤ `programs.nh.enable`（不设 flake、不开 clean）+ `nrs` 改走 `nh os switch --diff always .`（门控自 isLinux 收紧为 `isLinux && !isStandalone`，standalone 上原 sudo 形式同样必然失败）。

验证（本机求值/构建，未激活）：五输出 drvPath 求值全部通过；两主机 `time.timeZone` 经 vars 求值 `Asia/Shanghai`，`programs.nh.enable` 两边 `true`、`clean.enable` `false`、`flake` 未设。硬件层不在任何输出 import 链上（CI 不覆盖），四个 profile 经 `extendModules` 叠加 wsl 配置求值：nvidia 无 gpuBusIDs 时 prime 块缺省、注入 nvidia+intel 时 offload 与 `intelBusId` 正确接线，amd/intel early KMS 与 intel VA-API 包、vm-guest 两服务均按预期。模板经真实脚手架路径（仓库内 cp + sed）+ 桌面模块集（desktop.nix + hermes 模块 + 集成 HM）从零 `nixosSystem` 求值通过（hostname/systemd-boot/ext4 根/timeZone/hermes/HM 用户全对）；过程中确认 `networking.hostName` 的类型模式会拒绝未替换的 `__HOSTNAME__` 占位符（下划线不可开头）——sed 失败时求值大声失败。四脚本 `bash -n` 通过；linux.sh 日志以错误 target 触发用户守卫实跑验证（日志文件落盘且内容完整）。standalone x86_64 activationPackage 构建通过，仅 bashrc 相关 4 个派生重建（与 nrs 门控改动的预期影响面一致），产物 `home-files/.bashrc` 已无 `nrs`、`hms` 函数仍在。

未验证：`nh os switch` 实机切换（需 NixOS 桌面/WSL，桌面下次 `nrs` 即首验，注意确认代际 diff 输出）；GPU/VM profile 无实机；nixos.sh 脚手架流程未实跑（仅求值级验证，脚本路径改动经 bash -n + 逐段核对）；install 链路、macOS 输出、darwin/nixos 日志实跑（仅 linux.sh 前段实测）；CI 在本批提交上的运行（推送后自动触发）。

## 2026-09-18 WSL getty@tty1 mask（NixOS-WSL 26.11，本机）

改动：`hosts/wsl/default.nix` 增加 `systemd.units."getty@tty1.service".enable = false;`。背景：本机当日从 26.05 桌面代（systemd 257）切到 26.11 wsl 代（systemd 261）时，切换事务经 getty.target 拉起 `getty@tty1`，WSL 无真实 tty1，agetty 收 HUP 即退 → restart 循环 → start-limit，`switch-to-configuration` 以 status 4 失败、系统 degraded。诊断依据：开机段日志无任何 getty/Login Prompts 条目、静态配置与 generator 均无 tty1 的 wants 链接（generator 仅加已被 mask 的 console-getty）→ 正常开机不会拉起它，失败仅发生在跨版本切换事务内。

验证：该选项求值为 `false`；wsl toplevel 构建通过（`5pcvyqz4…`），产物 `etc/systemd/system/getty@tty1.service` 指向 `unit-getty-tty1.service-disabled`（即 `/dev/null` mask，与系统对 console-getty 的处理同机制）；桌面输出 `systemd.units` 无该单元声明，行为不变。未验证：实际 switch 激活与重启后 degraded 清除（待本机执行 `nixos-rebuild switch --flake .#wsl` + Windows 侧 `wsl --shutdown`，后者同时令 wsl.conf 的 hostname=wsl 生效）。

## 2026-09-17 架构收敛 + CI 构建层 + 文档重构（Fedora 44 / WSL2 standalone Nix）

改动：本地用户名单点移至仓库根 `meta.json`（`flake.nix` 经 `builtins.fromJSON` 读取；`bootstrap.sh`/`linux.sh`/`nixos.sh` 改为 sed 解析同一文件并在解析失败时中止——删掉了三处 `xuqihao` 静默兜底与 `darwin.sh` 的硬编码默认 target）；`pkgsFor` 统一实例化 unstable + stable（共享 `nixpkgsConfig`），`mkStandaloneHome` 不再内联 `import nixpkgs`；`stateVersion` 收敛到 flake 顶层单点并经 `specialArgs`/`extraSpecialArgs` 贯通 `home.stateVersion` 与 `system.stateVersion`；删除无消费者的 `supportedSystems`/`forAllSystems`；`hms` 从别名字符串改为 bash 函数（`programs.bash.initExtra`）；`eval.yml` 增加 standalone x86_64 activation package 构建步（含 runner 磁盘清理，timeout 30→45）；验证后移除共享 `nixpkgsConfig` 中无引用的 `electron-38.8.4`；验证记录拆至本文件。

验证（本机求值/构建，未激活）：五输出求值全部通过，`nixos`/`wsl` toplevel drvPath 与改动前基线**逐字节一致**（干净树对比；含移除 electron 条目后复测），standalone x86_64/aarch64/darwin 按预期变化——经 activationScripts / environment.etc / systemd.units / home.file / bash 选项的 JSON 语义 diff 确认差异仅为 standalone 侧 bashrc 中 `hms` 的别名→函数文本，NixOS 侧无任何语义差异。过程中发现并记录一个 HM 陷阱：`initExtra` 用字符串级 `lib.optionalString` 置空会生成多一个空行的 bashrc（与未设置不同），必须属性集级 `lib.optionalAttrs` 门控。五个 bootstrap 脚本 `bash -n` 通过；sed 提取 stub 测 6 例（正常/缺 key/缺文件/紧凑 JSON/仓库实文件/中止分支）全过；新 CI 构建步本地预演成功（除 HM 自身 5 个派生外全部 substituter 命中，成本可控）；`electron-38.8.4` 移除经五输出求值 + standalone 构建双向验证。

未验证：任何主机的实际激活、aarch64 实机构建、macOS、bootstrap 安装链路实跑、GitHub Actions 上新 workflow 步的运行（workflow 变更需手动双推后才生效）。

## 2026-09-17 follow-up pass on Fedora 44 / WSL2 standalone Nix (offline evaluation)

`bootstrap/bootstrap.sh` had been committed with mode 644 — fixed to 755 to match its siblings; the zsh session-vars append in `home/standalone-linux.nix` is now gated exactly like fish (login shell is zsh or `~/.zshrc` already exists), so bash-only hosts no longer get a stray `~/.zshrc` created on the next activation — this supersedes the unconditional zsh append described in the boundary-expansion entry below (whose live activation test ran in the separate Ubuntu 26.04 distro, not on the daily-driver Fedora 44 host where the committed blocks are still unactivated); README/AGENTS environment wording regularized (validation records name their distro explicitly; the README status table no longer pins the volatile distro name). All five outputs re-evaluate on the current lock after the gating edit; all bootstrap scripts pass `bash -n`. Unverified: live activation of the gated blocks on any host.

## 2026-09-17 boundary expansion on Ubuntu 26.04 / WSL2 standalone Nix (live host)

Added `homeConfigurations.xuqihao-aarch64` (aarch64-linux; shared Linux-only packages verified available at the locked revs — root 6.40.00 not broken, in platforms); `hms` and the new unified entry `bootstrap/bootstrap.sh` now select the standalone target by architecture; standalone Linux gained idempotent guarded zsh/fish session-vars appends in `home.activation` (live-activated here — the `~/.zshrc` guard block was created; fish only acts when fish is actually in use); `bootstrap/linux.sh` gained a WSL1 rejection, a single-user install branch (official installer `--no-daemon` for no-systemd/no-sudo hosts, mirrors in user-level nix.conf plus exported `NIX_CONFIG`, `/nix` one-time-root pre-flight with the exact admin command) and HM-symlink skip guards on the token/flakes steps (previously darwin-only). All five outputs evaluate on the current lock; desktop and WSL toplevel drvPaths are byte-identical to the previous commit, the darwin activation derivation is unchanged, and the x86_64 standalone drvPath changed as expected (hms alias text + new activation blocks). The unified entry ran end-to-end on the live host — a non-tty session auto-selected the single-user branch and exercised its idempotent guards, producing generation 2 — and dispatcher branches were stub-tested (Darwin, WSL1, aarch64/riscv64, zsh note, FreeBSD, explicit-arg override, suffix stripping). Unverified: an aarch64 hardware build, a genuinely rootless single-user install on a machine without sudo, and macOS.

## 2026-09-17 username single-point refactor on Fedora 44 / WSL2 standalone Nix (offline evaluation)

The local username is now defined once as `username = "xuqihao"` at the top of `flake.nix`'s `let` and flows to all NixOS modules and HM entries via `specialArgs`/`extraSpecialArgs` (`users.users.*`, `home-manager.users.*`, standalone output names, `mnt.nix` mount owner); `hms` gained a current-user guard that refuses cleanly on mismatch; `bootstrap/linux.sh`/`darwin.sh` abort up front when the target's username differs from the current login user; `bootstrap/nixos.sh` reads the password-setup username from `flake.nix`. All four outputs evaluate on the current lock; desktop and WSL toplevel drvPaths are byte-identical to the previous commit (semantics-preserving under the default username), standalone drvPaths changed as expected (new `hms` alias text). The `hms` accept/refuse branches, the bootstrap refusal and the flake-username extraction were runtime-tested locally with stubs. Nothing was built or activated; desktop boot, Darwin build and WSL activation remain unverified.

## 2026-09-16 repair/cleanup pass on Fedora 44 / WSL2 standalone Nix (offline evaluation)

After removing the stale `programs.dms-shell.enableSystemMonitoring` definition (removed upstream in the locked nixpkgs; it had broken desktop evaluation since the 2026-09-14 lock bump), all four outputs evaluate — desktop toplevel (hermes-agent input stubbed locally due to GitHub 429), WSL toplevel, standalone Linux and standalone Darwin activation packages. WSL and standalone Linux drvPaths were byte-identical across the P0/P1 edits, confirming those were semantics-preserving. Changes this pass: rustdesk-server disabled (placeholder relay host), podman commented out (docker stays), niri/hypr dotfiles now deployed via `home/default.nix`, orphan dotfiles deleted, `hms` gated behind `isStandalone`, the unused nixpkgs-master channel removed (flake.nix + flake.lock + all plumbing), plasma6/gnome kept with cosmic commented out. None of this was built or activated; desktop boot, Darwin build and WSL activation remain unverified.

## 2026-09-14 runtime split validation on NixOS 26.11 / WSL2

WSL system closure and standalone Linux activation package built without activation; standalone Darwin activation derivation and desktop system derivation evaluated. Desktop/WSL Node, pnpm, Python, R and ROOT package paths match exactly. The built WSL profile passed Node/npm/pnpm/uv execution, npm registry queries, all 15 configured Python module imports, and ROOT/R computations through PyROOT/rpy2. After restoring shared C++ ROOT, WSL and standalone Linux were rebuilt and the standalone artifact passed a C++ ROOT computation. This does not verify activation of these edits, a Darwin build, or desktop boot. Desktop full build remains unverified after a QQ source download failure; further QQ diagnosis was skipped and QQ is unchanged at the user's request.

## 2026-09-05 historical verification on AlmaLinux 9.8 / WSL2 standalone Nix

WSL's system closure built; the desktop host-layout refactor preserved its derivation; standalone Linux/Darwin activation derivations evaluated. These records predate later edits and do not certify the current lock/package set. Activation and subsequent boot/login of the current WSL edits, and a Darwin build, remain unverified; the 2026-09-14 checks exercised build artifacts without activating these edits. GitHub synchronization was separately verified by pushing a documentation commit only to Gitee and observing Actions update GitHub.
