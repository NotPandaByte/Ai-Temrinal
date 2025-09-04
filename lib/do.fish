# Simple task execution implementation

function ai_do
    if test (count $argv) -lt 1
        echo "Usage: ai do \"task description\""
        return 1
    end
    set -l task (string join " " -- $argv)

    # Detect OS / package manager
    set -l os_id unknown
    if test -f /etc/os-release
        set -l line (grep -E '^ID=' /etc/os-release | head -n1)
        if test -n "$line"
            set os_id (string replace -r '^ID="?(.*?)"?$' '$1' -- $line)
        end
    end
    set -l have_cmds
    function __has
        command -q $argv[1]
    end
    if __has pacman
        set have_cmds pacman
    else if __has apt
        set have_cmds apt
    else if __has dnf
        set have_cmds dnf
    else if __has zypper
        set have_cmds zypper
    else if __has brew
        set have_cmds brew
    end

    set -l plan
    set -l needs_sudo 1
    set -l confirm_hint "Type YES to confirm: "

    # Very simple planner for common tasks
    set -l task_lc (string lower -- $task)
    if string match -qr 'update|upgrade' -- $task_lc
        switch $have_cmds
            case pacman
                set plan 'sudo pacman -Syu'
            case apt
                set plan 'sudo apt update && sudo apt upgrade -y'
            case dnf
                set plan 'sudo dnf upgrade --refresh -y'
            case zypper
                set plan 'sudo zypper refresh && sudo zypper update -y'
            case brew
                set plan 'brew update && brew upgrade'
                set needs_sudo 0
            case '*'
                echo "No known package manager found. Aborting."; return 1
        end
    else
        echo "Unsupported task. Currently supported: update/upgrade"; return 1
    end

    echo "Planned commands for: $task"
    echo "OS: $os_id  PM: $have_cmds"
    echo "Will run: $plan"
    read -P $confirm_hint ok
    if test (string upper -- $ok) != YES
        echo "Cancelled."; return 1
    end

    # Execute safely
    if test $needs_sudo -eq 1
        if not command -q sudo
            echo "sudo not found; cannot elevate."; return 1
        end
    end
    eval $plan
    set status_code $status
    if test $status_code -ne 0
        echo "Command failed with status $status_code"; return $status_code
    end
    echo "Done."
end
