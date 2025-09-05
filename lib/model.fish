# Model management implementation

function ai_model
    if test (count $argv) -ge 1
        set -l new_model $argv[1]
        set -l installed (ollama list | awk 'NR>1 {print $1}')
        set -l target $new_model
        if not contains -- $target $installed
            echo "Pulling $target ..."
            ollama pull "$target"
            if test $status -ne 0
                set -l alt (string replace -a -- "-instruct" "" $target)
                if test "$alt" != "$target"
                    echo "Pull failed, trying $alt ..."
                    ollama pull "$alt"
                    if test $status -eq 0
                        set target $alt
                    end
                end
                if test "$target" = "$new_model"
                    set -l base (string split -m 1 ':' -- $target)[1]
                    if test -n "$base"
                        echo "Pull failed, trying $base ..."
                        ollama pull "$base"
                        if test $status -eq 0
                            set target $base
                        end
                    end
                end
                if test "$target" = "$new_model"
                    echo "Failed to pull $new_model. Edit ~/.config/ai/models.txt with a valid tag."
                    return 1
                end
            end
        end
        # Unload other models to free up resources
        echo "Unloading other models to optimize performance..."
        set -l loaded_models (ollama ps --format json 2>/dev/null | jq -r '.[].name' 2>/dev/null)
        if test -z "$loaded_models"
            # Fallback without jq
            set loaded_models (ollama ps 2>/dev/null | awk 'NR>1 {print $1}')
        end
        
        for model in $loaded_models
            if test "$model" != "$target"
                echo "Unloading: $model"
                ollama stop "$model" 2>/dev/null
            end
        end
        
        set -Ux MODEL $target
        set -g MODEL $target
        # Add to models.txt if not already there
        set -l config_dir $HOME/.config/ai
        set -l models_file $config_dir/models.txt
        if test -f "$models_file"
            if not grep -q "^$target\$" "$models_file"
                echo "$target" >> "$models_file"
                echo "Added $target to your models list"
            end
        end
        
        echo "Default model set to: $target"
        echo "Other models unloaded for optimal performance"
        return 0
    end

    set -l config_dir $HOME/.config/ai
    set -l config_file $config_dir/models.txt
    if not test -f $config_file
        mkdir -p $config_dir
        printf "%s\n" \
            "qwen2.5:7b-instruct" \
            "llama3.1:8b-instruct" \
            "qwen2.5:14b-instruct" \
            "mixtral:8x7b-instruct" \
            "qwen2.5:32b-instruct" > $config_file
    end

    set -l candidates
    for line in (cat $config_file)
        if string match -qr '^\s*$' -- $line
            continue
        end
        if string match -qr '^\s*#' -- $line
            continue
        end
        set candidates $candidates $line
    end
    if test (count $candidates) -eq 0
        echo "No candidates in $config_file"
        return 1
    end

    set -l chosen
    if type -q fzf
        set -l display
        for m in $candidates
            set -l specs (model_specs $m)
            set display $display "$m :: $specs"
        end
        set -l chosen_line (printf "%s\n" $display | fzf --prompt="Choose model: ")
        if test -n "$chosen_line"
            set chosen (string split -m 1 ' :: ' -- $chosen_line)[1]
        end
    end
    if test -z "$chosen"
        echo "Available models:"
        for i in (seq (count $candidates))
            set -l m $candidates[$i]
            set -l specs (model_specs $m)
            echo "  $i) $m — $specs"
        end
        read -P "Select model number or name: " selection
        set selection (string trim -- $selection)
        if test -z "$selection"
            echo "No selection provided"
            return 1
        end
        # If numeric, pick by index
        if string match -rq '^[0-9]+$' -- $selection
            if test $selection -lt 1; or test $selection -gt (count $candidates)
                echo "Selection out of range"
                return 1
            end
            set chosen $candidates[$selection]
        else
            # Otherwise allow choosing by exact model name in the list
            if contains -- $selection $candidates
                set chosen $selection
            else
                echo "Unknown model: $selection"
                echo "Valid options:"
                for i in (seq (count $candidates))
                    echo "  $i) $candidates[$i]"
                end
                return 1
            end
        end
    end

    set -l installed (ollama list | awk 'NR>1 {print $1}')
    set -l target $chosen
    if not contains -- $target $installed
        echo "Pulling $target ..."
        ollama pull "$target"
        if test $status -ne 0
            set -l alt (string replace -a -- "-instruct" "" $target)
            if test "$alt" != "$target"
                echo "Pull failed, trying $alt ..."
                ollama pull "$alt"
                if test $status -eq 0
                    set target $alt
                end
            end
            if test "$target" = "$chosen"
                set -l base (string split -m 1 ':' -- $target)[1]
                if test -n "$base"
                    echo "Pull failed, trying $base ..."
                    ollama pull "$base"
                    if test $status -eq 0
                        set target $base
                    end
                end
            end
            if test "$target" = "$chosen"
                echo "Failed to pull $chosen. Edit ~/.config/ai/models.txt with a valid tag."
                return 1
            end
        end
    end

    # Unload other models to free up resources
    echo "Unloading other models to optimize performance..."
    set -l loaded_models (ollama ps --format json 2>/dev/null | jq -r '.[].name' 2>/dev/null)
    if test -z "$loaded_models"
        # Fallback without jq
        set loaded_models (ollama ps 2>/dev/null | awk 'NR>1 {print $1}')
    end
    
    for model in $loaded_models
        if test "$model" != "$target"
            echo "Unloading: $model"
            ollama stop "$model" 2>/dev/null
        end
    end
    
    # Add to models.txt if not already there
    set -l config_dir $HOME/.config/ai
    set -l models_file $config_dir/models.txt
    if test -f "$models_file"
        if not grep -q "^$target\$" "$models_file"
            echo "$target" >> "$models_file"
            echo "Added $target to your models list"
        end
    end
    
    set -Ux MODEL $target
    set -g MODEL $target
    echo "Default model set to: $target"
    echo "Other models unloaded for optimal performance"
end
