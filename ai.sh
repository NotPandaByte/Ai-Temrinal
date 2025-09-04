#!/usr/bin/env fish

# Initialize MODEL if not set
if not set -q MODEL
    set MODEL "qwen2.5:7b-instruct"
end

# Get the directory of this script (resolve symlinks)
set -l script_dir (dirname (realpath (status --current-filename)))

# Source all library modules
source $script_dir/lib/common.fish
source $script_dir/lib/help.fish
source $script_dir/lib/setup.fish
source $script_dir/lib/rules.fish
source $script_dir/lib/model.fish
source $script_dir/lib/agent.fish

# Main command dispatcher
if test (count $argv) -eq 0
    echo "Usage: ai \"your prompt\"  |  ai help"
    exit 1
end

switch $argv[1]
    case "help"
        ai_help
    case "setup"
        ai_setup
    case "rules"
        ai_rules $argv[2..-1]
    case "rule"
        echo "'ai rule' is deprecated. Use 'ai rules' or 'ai rules edit'."
        exit 1
    case "model"
        ai_model $argv[2..-1]
    case "agent"
        ai_agent $argv[2..-1]
    case "*"
        # Default: run as prompt
        set -l prompt (string join " " -- $argv)
        
        set -l rules_file $HOME/.config/ai/rules.txt
        set -l combined $prompt
        if test -f $rules_file
            set -l raw_rules (cat $rules_file)
            if test (count $raw_rules) -gt 0
                set -l rules_text (string join "\n" -- $raw_rules)
                set combined (printf "%s\n\n%s" "Rules:\n$rules_text" "$prompt")
            end
        end
        
        printf "\n\nai response:\n"
        ollama run $MODEL "$combined"
end