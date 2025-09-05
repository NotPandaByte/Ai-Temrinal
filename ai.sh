#!/usr/bin/env fish

# Initialize MODEL from config file or default
set -l config_dir $HOME/.config/ai
set -l model_config $config_dir/current_model.txt

if test -f $model_config
    set MODEL (cat $model_config | string trim)
else
    mkdir -p $config_dir
    set MODEL "qwen2.5:7b-instruct"
    echo $MODEL > $model_config
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
source $script_dir/lib/search.fish
source $script_dir/lib/optimize.fish

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
    case "search"
        ai_search $argv[2..-1]
    case "optimize"
        ai_optimize $argv[2..-1]
    case "*"
        # Check for special modes first
        set -l debug_mode false
        set -l reasoning_mode false
        
        if test "$argv[1]" = "--debug"
            set debug_mode true
            set argv $argv[2..-1]  # Remove --debug from args
        else if test "$argv[1]" = "--reasoning" -o "$argv[1]" = "--think"
            set reasoning_mode true
            set argv $argv[2..-1]  # Remove reasoning flag from args
        end
        
        # Default: run as prompt
        set -l prompt (string join " " -- $argv)
        
        # Ensure GPU mode and optimize for performance
        # Unset CPU-only mode if it was set
        set -e OLLAMA_NO_GPU 2>/dev/null
        
        # Set optimal GPU settings
        set -gx OLLAMA_GPU_LAYERS 999  # Use GPU for all layers
        set -gx OLLAMA_FLASH_ATTENTION 1  # Enable flash attention if available
        
        # Check if model is loaded, if not load it
        set -l loaded_models (ollama ps --format json 2>/dev/null | jq -r '.[].name' 2>/dev/null)
        if test -z "$loaded_models"
            set loaded_models (ollama ps 2>/dev/null | awk 'NR>1 {print $1}')
        end
        
        # If current model isn't loaded, ensure it's the only one running
        if not contains -- $MODEL $loaded_models
            echo "Loading $MODEL on GPU..."
            # Unload other models first for optimal GPU memory
            for model in $loaded_models
                if test -n "$model" -a "$model" != "$MODEL"
                    ollama stop "$model" 2>/dev/null
                end
            end
        end
        
        set -l combined $prompt
        
        # Apply reasoning mode if enabled
        if test "$reasoning_mode" = "true"
            set combined "Think step by step about this request and show your reasoning process.

User request: $prompt

Please structure your response as:

**Reasoning:**
[Show your thought process, analysis, and step-by-step thinking]

**Answer:**
[Give your final answer]"
        else
            # Apply rules if they exist  
            set -l rules_file $HOME/.config/ai/rules.txt
            if test -f $rules_file; and test -s $rules_file
                set -l rules_content (cat $rules_file | string trim)
                if test -n "$rules_content"
                    set combined "Instructions: $rules_content

User request: $prompt

Please follow the instructions above when responding to the user request."
                end
            end
        end
        
        # Debug mode: show the actual prompt being sent
        if test "$debug_mode" = "true"
            echo "=== DEBUG: Full prompt being sent ==="
            echo "$combined"
            echo "=== END DEBUG ==="
            return 0
        end
        
        printf "\n\nai response:\n"
        ollama run $MODEL "$combined"
end