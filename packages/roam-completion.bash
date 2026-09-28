# packages/roam-completion.bash — `roam` 的 bash 补全
#
# 由 packages/roam.nix 经 symlinkJoin 与 bin/roam 合并成同一个包，落在
# share/bash-completion/completions/roam：bash-completion（≥2.12）按
# $XDG_DATA_DIRS 下的 bash-completion/completions/ 搜索并按需懒加载——
# standalone 侧 HM 把 ~/.nix-profile/share 注入 XDG_DATA_DIRS，NixOS 侧
# /share/bash-completion 默认链入 system sw，两侧均免额外接线。
#
# 注意：本文件不经过 writeShellApplication 的 bash -n + shellcheck 门，
# 改动后手动自查。子命令/旗标清单与 packages/roam.sh 的 case 分发、
# bootstrap/gc.sh 的参数保持同步（人工维护）。
# 只用 bash 内建 + compgen/completion；不依赖 _init_completion 等
# bash-completion 内部助手（跨版本名不稳），macOS Bash 3.2 兼容。

_roam()
{
    local cur prev sub i w list
    cur="${COMP_WORDS[COMP_CWORD]}"
    if [ "$COMP_CWORD" -gt 0 ]; then
        prev="${COMP_WORDS[$((COMP_CWORD - 1))]}"
    else
        prev=""
    fi
    COMPREPLY=()

    # 已输入的子命令 = 第 1..cword-1 个词里第一个非 - 开头者
    sub=""
    i=1
    while [ "$i" -lt "$COMP_CWORD" ]; do
        w="${COMP_WORDS[$i]}"
        case "$w" in
            -*) ;;
            *) sub="$w"; break ;;
        esac
        i=$((i + 1))
    done

    if [ -z "$sub" ]; then
        # 一级：子命令 + 帮助
        list="switch status doctor rollback gc check update info help -h --help"
    else
        case "$sub" in
            switch | status | doctor | info | help)
                # 无自有补全（switch 透传 nh，不猜第三方旗标）
                return 0
                ;;
            rollback)
                # 世代号按宿主取（只读本地 profile，排除当前世代），失败静默为空
                if [ -f /etc/NIXOS ]; then
                    list="$(nix-env -p /nix/var/nix/profiles/system --list-generations 2>/dev/null \
                        | grep -v 'current' | sed -n 's/^\([0-9][0-9]*\).*/\1/p' | tr '\n' ' ')"
                elif command -v home-manager >/dev/null 2>&1; then
                    list="$(home-manager generations 2>/dev/null | grep -v '(current)' \
                        | sed -n 's/.* : id \([0-9][0-9]*\) ->.*/\1/p' | tr '\n' ' ')"
                else
                    list=""
                fi
                list="--list -y --yes $list"
                ;;
            gc)
                if [ "$prev" = "--older-than" ]; then
                    list="7d 14d 30d"
                else
                    list="--dry-run --all --system --older-than"
                fi
                ;;
            check)
                list="--build nixos wsl x86_64-linux aarch64-linux aarch64-darwin"
                ;;
            update)
                # 输入名从 flake.lock 动态取（与 cmd_update 的 choose_inputs 同源数据）；
                # 无 jq / 无 flake.lock 时只补旗标——与子命令自身的降级行为一致
                list=""
                if [ -r flake.lock ] && command -v jq >/dev/null 2>&1; then
                    list="$(jq -r '.nodes.root.inputs // {} | keys[]' flake.lock 2>/dev/null | tr '\n' ' ')"
                fi
                list="-a --all $list"
                ;;
            *)
                # 未知子命令（多为笔误）：不补，避免误导
                return 0
                ;;
        esac
    fi

    while IFS= read -r w; do
        COMPREPLY+=("$w")
    done < <(compgen -W "$list" -- "$cur")
    return 0
}

complete -F _roam roam
