# AI agent implementation

function ai_agent
    if test (count $argv) -lt 1
        echo "Usage: ai agent \"task description\""
        return 1
    end
    set -l task (string join " " -- $argv)
    set -l ctx (__ai_sys_context)
    set -l prompt_text (printf "%s\n\nTask: %s\n\nReturn ONLY JSON: {\"plan\": [\"cmd1\", \"cmd2\", ...], \"explain\": \"brief reason\"}.\n\nGuidelines:\n- For information gathering: use commands like 'nvidia-smi', 'lspci', 'systemctl status', 'ps aux', 'df -h', etc.\n- For updates/installs: use appropriate package manager from context\n- Use sudo only when absolutely needed\n- Prefer read-only commands when possible\n- Be safe and avoid destructive operations\n- Multiple commands are allowed for complex tasks\n\nExamples:\n- \"show nvidia drivers\" -> [\"nvidia-smi\", \"lspci | grep -i nvidia\"]\n- \"check disk space\" -> [\"df -h\", \"du -sh /home\"]\n- \"update system\" -> [\"sudo pacman -Syu\"]\n" "Context:\n$ctx" "$task")

    # Ask the model to propose commands
    set -l raw (ollama run $MODEL "$prompt_text")
    set -l json (__ai_extract_json "$raw")
    set -l plan
    set -l explain
    # Minimal JSON parsing using jq if available
    if command -q jq
        set plan (printf "%s" "$json" | jq -r '.plan[]?' 2>/dev/null)
        set explain (printf "%s" "$json" | jq -r '.explain // empty' 2>/dev/null)
    else
        # Fallback: naive line split for "plan"
        set plan (printf "%s" "$json" | string match -r '"plan"\s*:\s*\[(.*?)\]' | string replace -r '.*\[(.*)\].*' '$1' | string split ',' | string replace -r '^\s*"|"\s*$' '')
        set explain (printf "%s" "$json" | string match -r '"explain"\s*:\s*"(.*?)"' | string replace -r '.*:"(.*)".*' '$1')
    end

    if test -z "$plan"
        echo "Agent failed to propose a plan. Output was:"; echo "$raw"; return 1
    end

    echo "Proposed commands:"
    for c in $plan
        echo "  $c"
    end
    if test -n "$explain"
        echo "Reason: $explain"
    end
    read -P "Type YES to run, NO to cancel: " ok
    set ok (string upper -- (string trim -- $ok))
    if test "$ok" != YES
        echo "Cancelled."; return 1
    end

    # Execute each command sequentially; stop on failure
    for c in $plan
        echo "Running: $c"
        eval $c
        set code $status
        if test $code -ne 0
            echo "Command failed ($code): $c"; return $code
        end
    end
    echo "Done."
end
