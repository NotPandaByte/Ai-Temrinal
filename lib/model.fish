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
        
        # Save to config file for persistence
        set -l config_dir $HOME/.config/ai
        set -l model_config $config_dir/current_model.txt
        mkdir -p $config_dir
        echo $target > $model_config
        
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
            "# Small & Fast Models (1-4GB)" \
            "tinyllama:1.1b" \
            "phi3:mini" \
            "gemma2:2b" \
            "qwen2.5:3b" \
            "llama3.2:3b" \
            "orca-mini:3b" \
            "" \
            "# Medium Models (4-8GB)" \
            "qwen2.5:7b-instruct" \
            "llama3.1:8b" \
            "mistral:7b" \
            "codellama:7b" \
            "gemma2:9b" \
            "phi3:medium" \
            "llama3.2:1b" \
            "" \
            "# Large Models (8-16GB)" \
            "qwen2.5:14b-instruct" \
            "llama3.1:70b-instruct-q4_0" \
            "mixtral:8x7b" \
            "solar:10.7b" \
            "deepseek-coder:6.7b" \
            "" \
            "# Specialized Models" \
            "codellama:13b" \
            "wizardcoder:15b" \
            "falcon:7b" \
            "vicuna:7b" \
            "nous-hermes:7b" \
            "orca2:7b" \
            "" \
            "# Very Large Models (16GB+)" \
            "qwen2.5:32b-instruct" \
            "llama3.1:70b" \
            "mixtral:8x22b" > $config_file
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

    # Show management options first
    echo "Model Management:"
    echo "  d) Delete installed models"
    echo "  r) Refresh/update models list"
    echo "  Or select a model number to switch:"
    echo
    
    set -l chosen
    if type -q fzf
        set -l display
        for m in $candidates
            set -l specs (model_specs $m)
            set -l size_info (get_model_size $m)
            set -l status_info ""
            # Check if model is installed
            set -l installed_check (ollama list | grep "^$m " | awk '{print $1}')
            if test -n "$installed_check"
                set status_info " ✅"
            else
                set status_info ""
            end
            set display $display "$m :: $specs :: $size_info$status_info"
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
            set -l size_info (get_model_size $m)
            set -l status_info ""
            # Check if model is installed
            set -l installed_check (ollama list | grep "^$m " | awk '{print $1}')
            if test -n "$installed_check"
                set status_info " ✅"
            else
                set status_info ""
            end
            echo "  $i) $m — $specs — $size_info$status_info"
        end
        echo
        read -P "Select model number, name, or option (d/r): " selection
        set selection (string trim -- $selection)
        if test -z "$selection"
            echo "No selection provided"
            return 1
        end
        
        # Handle special options
        if test "$selection" = "d"
            # Delete models functionality
            echo "🗑️  Delete Installed Models"
            echo
            set -l installed_models (ollama list | awk 'NR>1 {printf "%s [%s]\n", $1, $3}')
            if test -z "$installed_models"
                echo "No models installed"
                return 0
            end
            
            echo "Installed models:"
            set -l model_names (ollama list | awk 'NR>1 {print $1}')
            for i in (seq (count $model_names))
                set -l name $model_names[$i]
                set -l size (ollama list | grep "^$name " | awk '{print $3}')
                echo "  $i) $name [$size]"
            end
            echo
            
            read -P "Select model to delete (number or 'all'): " del_choice
            if test "$del_choice" = "all"
                read -P "Delete ALL models? Type 'DELETE ALL' to confirm: " confirm
                if test "$confirm" = "DELETE ALL"
                    for model in $model_names
                        echo "Deleting: $model"
                        ollama rm "$model"
                    end
                    echo "✅ All models deleted"
                else
                    echo "Cancelled"
                end
            else if string match -rq '^[0-9]+$' -- $del_choice
                if test $del_choice -ge 1; and test $del_choice -le (count $model_names)
                    set -l model_to_delete $model_names[$del_choice]
                    read -P "Delete $model_to_delete? Type 'DELETE' to confirm: " confirm
                    if test "$confirm" = "DELETE"
                        ollama rm "$model_to_delete"
                        echo "✅ Deleted $model_to_delete"
                    else
                        echo "Cancelled"
                    end
                else
                    echo "Invalid selection"
                end
            else
                echo "Invalid choice"
            end
            return 0
            
        else if test "$selection" = "r"
            # Refresh models list
            echo "🔄 Refreshing models list..."
            rm -f "$config_file"
            echo "✅ Models list will be regenerated on next run"
            echo "Run 'ai model' again to see the updated list"
            return 0
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
                echo "  d) Delete models"
                echo "  r) Refresh list"
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
    
    # Save to config file for persistence
    set -l config_dir $HOME/.config/ai
    set -l model_config $config_dir/current_model.txt
    mkdir -p $config_dir
    echo $target > $model_config
    
    set -g MODEL $target
    echo "Default model set to: $target"
    echo "Other models unloaded for optimal performance"
end
