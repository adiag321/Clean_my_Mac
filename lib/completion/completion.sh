#!/bin/bash
# lib/completion/completion.sh — Shell completions for bash and zsh.
# Source this file; do not execute directly.

run_completion() {
    local shell_type="${1:-zsh}"

    case "$shell_type" in
        zsh)
            cat <<'EOF'
#compdef maccleanup

_maccleanup() {
    local -a commands
    commands=(
        'clean:Deep cache, log, and leftover cleanup'
        'uninstall:Smart app uninstaller with leftover cleanup'
        'optimize:System maintenance: DNS, icon cache, QuickLook, LaunchServices'
        'analyze:Interactive disk usage explorer'
        'status:Live system health monitor (CPU, RAM, disk, network)'
        'purge:Dev build artifact purge (node_modules, target, .build)'
        'installer:Stale installer files cleanup (.dmg, .pkg, .iso)'
        'slim:Universal binary slimmer (remove Intel slices on Apple Silicon)'
        'touchid:Enable or check Touch ID for sudo authentication'
        'history:View operation log history'
        'whitelist:Manage protected paths'
        'config:Manage configuration file'
        'update:Self-updater'
        'completion:Generate shell tab completion'
        'help:Display help information'
        'version:Show version'
    )

    local -a global_flags
    global_flags=(
        '--dry-run[Preview changes without deleting anything]'
        '--debug[Enable verbose debug logs]'
        '--whitelist[Manage whitelisted paths]'
        '--system[Include system logs and diagnostics (requires sudo)]'
        '--help[Show help]'
        '--version[Show version]'
    )

    _arguments -C \
        '1: :->command' \
        '*:: :->args'

    case $state in
        command)
            _describe -t commands 'maccleanup command' commands
            ;;
        args)
            case $line[1] in
                clean)
                    _arguments \
                        '--dry-run[Preview without deleting]' \
                        '--system[Include system logs and diagnostics]' \
                        '--whitelist[Manage whitelist]' \
                        '--no-orphans[Skip orphaned app data scan]'
                    ;;
                uninstall)
                    _arguments \
                        '--dry-run[Preview leftover files without deleting]' \
                        '--permanent[Delete permanently instead of moving to Trash]' \
                        '--with-data[Also remove personal data (Application Support, Containers)]' \
                        '--list[Print installed apps as JSON and exit]' \
                        '1:app name:_files -W /Applications -g "*.app(N:r)"'
                    ;;
                optimize)
                    _arguments \
                        '--dry-run[Preview maintenance tasks]' \
                        '--reindex-spotlight[Force full Spotlight reindex]'
                    ;;
                analyze)
                    _arguments \
                        '--threshold[Minimum file size in MB]:threshold (MB):' \
                        '1:target directory:_files -/'
                    ;;
                status)
                    _arguments \
                        '--once[Print single snapshot and exit]' \
                        '--json[Print single JSON snapshot and exit]' \
                        '--watch[Stream newline-delimited JSON snapshots]' \
                        '--interval[Refresh interval in seconds]:seconds:'
                    ;;
                purge)
                    _arguments \
                        '--dry-run[Preview stale directories]' \
                        '--days[Minimum age in days]:days:'
                    ;;
                installer)
                    _arguments \
                        '--dry-run[Preview stale installer files]' \
                        '--days[Minimum age in days]:days:'
                    ;;
                slim)
                    _arguments \
                        '--dry-run[Preview reclaimable space without stripping binaries]'
                    ;;
                touchid)
                    _arguments \
                        '1:action:(enable disable status)'
                    ;;
                history)
                    _arguments \
                        '--json[Output history in JSON format]' \
                        '--clear[Clear operation history log]'
                    ;;
                whitelist)
                    _arguments \
                        '1:action:(list add remove clear)' \
                        '2:path:_files'
                    ;;
                config)
                    _arguments \
                        '1:action:(show edit path reset)'
                    ;;
                completion)
                    _arguments \
                        '1:shell:(zsh bash)'
                    ;;
            esac
            ;;
    esac
}

_maccleanup "$@"
EOF
            ;;

        bash)
            cat <<'EOF'
# bash completion for maccleanup
_maccleanup_completions() {
    local cur prev words cword
    _init_completion || return

    local commands="clean uninstall optimize analyze status purge installer slim touchid history whitelist config update completion help version"
    local global_flags="--dry-run --debug --system --help --version"

    if [[ $cword -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "$commands $global_flags" -- "$cur") )
        return 0
    fi

    local subcmd="${words[1]}"
    case "$subcmd" in
        clean)
            COMPREPLY=( $(compgen -W "--dry-run --system --whitelist --no-orphans" -- "$cur") )
            ;;
        uninstall)
            COMPREPLY=( $(compgen -W "--dry-run --permanent --with-data --list" -- "$cur") )
            ;;
        optimize)
            COMPREPLY=( $(compgen -W "--dry-run --reindex-spotlight" -- "$cur") )
            ;;
        analyze)
            COMPREPLY=( $(compgen -W "--threshold" -- "$cur") )
            ;;
        status)
            COMPREPLY=( $(compgen -W "--once --json --watch --interval" -- "$cur") )
            ;;
        purge|installer)
            COMPREPLY=( $(compgen -W "--dry-run --days" -- "$cur") )
            ;;
        slim)
            COMPREPLY=( $(compgen -W "--dry-run" -- "$cur") )
            ;;
        touchid)
            COMPREPLY=( $(compgen -W "enable disable status" -- "$cur") )
            ;;
        history)
            COMPREPLY=( $(compgen -W "--json --clear" -- "$cur") )
            ;;
        whitelist)
            COMPREPLY=( $(compgen -W "list add remove clear" -- "$cur") )
            ;;
        config)
            COMPREPLY=( $(compgen -W "show edit path reset" -- "$cur") )
            ;;
        completion)
            COMPREPLY=( $(compgen -W "zsh bash" -- "$cur") )
            ;;
    esac
}

complete -F _maccleanup_completions maccleanup
EOF
            ;;
        *)
            echo "Usage: maccleanup completion [zsh|bash]"
            return 1
            ;;
    esac
}
