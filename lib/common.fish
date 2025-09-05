# Common functions and utilities

function model_specs
    set model $argv[1]
    switch $model
        case 'qwen2.5:7b*' 'llama3.1:8b*'
            echo '≈6–8 GB VRAM (Q4) • 16+ GB RAM CPU'
        case 'qwen2.5:14b*'
            echo '≈10–12 GB VRAM (Q4) • 24+ GB RAM CPU'
        case 'mixtral:8x7b*'
            echo '≈24–32 GB VRAM (Q4) • 48–64 GB RAM CPU'
        case 'qwen2.5:32b*'
            echo '≈20–24 GB VRAM (Q4) • 48–64 GB RAM CPU'
        case '*'
            echo 'specs vary'
    end
end

function get_model_size
    set -l model $argv[1]
    
    # First check if model is installed and get actual size
    set -l installed_size (ollama list 2>/dev/null | grep "^$model " | awk '{print $3}')
    if test -n "$installed_size"
        echo "$installed_size"
        return
    end
    
    # Fallback: estimate based on model name/parameters
    switch $model
        case "*1.1b*" "*1b*"
            echo "~0.6GB"
        case "*2b*"
            echo "~1.3GB"
        case "*3b*"
            echo "~1.8GB"
        case "*6.7b*"
            echo "~3.7GB"
        case "*7b*"
            echo "~4.1GB"
        case "*8b*"
            echo "~4.7GB"
        case "*9b*"
            echo "~5.2GB"
        case "*10.7b*"
            echo "~6.1GB"
        case "*13b*"
            echo "~7.4GB"
        case "*14b*"
            echo "~8.2GB"
        case "*15b*"
            echo "~8.5GB"
        case "*32b*"
            echo "~18GB"
        case "*70b*q4*" "*70b*Q4*"
            echo "~40GB"
        case "*70b*"
            echo "~70GB"
        case "*8x7b*"
            echo "~26GB"
        case "*8x22b*"
            echo "~87GB"
        case "*mini*"
            echo "~2.3GB"
        case "*medium*"
            echo "~7.9GB"
        case '*'
            echo "~?GB"
    end
end

function __ai_open_in_editor
    set -l file $argv[1]
    set -l editor
    if set -q AI_EDITOR
        set editor $AI_EDITOR
    else if set -q EDITOR
        set editor $EDITOR
    else if type -q nano
        set editor nano
    else if type -q nvim
        set editor nvim
    else if type -q vim
        set editor vim
    else
        set editor vi
    end
    $editor $file
end

function __ai_require
    set -l bin $argv[1]
    if not command -q $bin
        echo "Missing dependency: $bin"
        echo "Please install $bin and retry."
        return 1
    end
    return 0
end

function __ai_sys_context
    set -l ctx
    set -l os_id unknown
    if test -f /etc/os-release
        set -l line (grep -E '^ID=' /etc/os-release | head -n1)
        if test -n "$line"
            set os_id (string replace -r '^ID="?(.*?)"?$' '$1' -- $line)
        end
    end
    set -l pm (begin; command -q pacman; and echo pacman; end)
    if test -z "$pm"; command -q apt; and set pm apt; end
    if test -z "$pm"; command -q dnf; and set pm dnf; end
    if test -z "$pm"; command -q zypper; and set pm zypper; end
    if test -z "$pm"; command -q brew; and set pm brew; end
    set -l kernel (uname -sr)
    set -l has_sudo (command -q sudo; and echo yes; or echo no)
    set ctx (printf "%s\n%s\n%s\n%s\n" "os_id=$os_id" "package_manager=$pm" "kernel=$kernel" "sudo=$has_sudo")
    echo $ctx
end

function __ai_extract_json
    # Try to extract a single JSON object from arbitrary text
    set -l text $argv[1]
    set -l start (string match -r -n -- '\{' "$text" | string split ' ' | head -n1)
    set -l end (string match -r -n -- '\}$' "$text")
    if test -z "$start"
        # fallback: take everything
        echo $text
        return 0
    end
    set -l json (string sub -s $start "$text")
    # Remove code fences if present
    set json (string replace -r '^```(json)?' '' -- $json)
    set json (string replace -r '```$' '' -- $json)
    echo $json
end
