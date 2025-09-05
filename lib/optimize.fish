# Model optimization and system performance management

function ai_optimize
    # If subcommand provided, use it directly (backward compatibility)
    if test (count $argv) -gt 0 -a "$argv[1]" != ""
        set -l cmd $argv[1]
        if contains -- $cmd "status" "unload" "quantize" "nvidia" "memory" "cleanup"
            __ai_optimize_execute $cmd
            return $status
        end
    end
    
    # Interactive picker
    echo "🚀 AI System Optimization"
    echo
    echo "Choose optimization action:"
    echo "  1) System Status     - Show loaded models and performance info"
    echo "  2) Unload Models     - Free up memory by unloading all models"
    echo "  3) Quantize Models   - Create smaller, faster model versions"
    echo "  4) NVIDIA Settings   - Optimize GPU performance settings"
    echo "  5) Memory Analysis   - Check memory usage and get tips"
    echo "  6) Cleanup Files     - Remove unused model files"
    echo
    
    read -P "Select option (1-6): " choice
    
    switch $choice
        case "1"
            __ai_optimize_execute "status"
        case "2"
            __ai_optimize_execute "unload"
        case "3"
            __ai_optimize_execute "quantize"
        case "4"
            __ai_optimize_execute "nvidia"
        case "5"
            __ai_optimize_execute "memory"
        case "6"
            __ai_optimize_execute "cleanup"
        case "*"
            echo "Invalid selection. Use 1-6."
            return 1
    end
end

function __ai_optimize_execute
    switch $argv[1]
        case "status"
            echo "=== AI System Status ==="
            echo
            
            # Show loaded models
            echo "📦 Loaded Models:"
            set -l loaded_models (ollama ps 2>/dev/null)
            if test $status -eq 0 -a -n "$loaded_models"
                echo "$loaded_models"
            else
                echo "No models currently loaded"
            end
            echo
            
            # Show available models
            echo "💾 Available Models:"
            ollama list 2>/dev/null | head -10
            echo
            
            # Show GPU info if available
            echo "🖥️  GPU Status:"
            if command -q nvidia-smi
                nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | while read -l line
                    set -l parts (string split ',' "$line")
                    if test (count $parts) -ge 5
                        echo "  GPU: $parts[1]"
                        echo "  Memory: $parts[2] MB / $parts[3] MB ("(math "round($parts[2] * 100 / $parts[3])")"% used)"
                        echo "  Utilization: $parts[4]%"
                        echo "  Temperature: $parts[5]°C"
                    end
                end
            else
                echo "  nvidia-smi not available"
            end
            echo
            
            # Show system memory
            echo "💭 System Memory:"
            if command -q free
                free -h | grep -E "Mem:|Swap:"
            end
            
        case "unload"
            echo "🔄 Unloading all models..."
            set -l loaded_models (ollama ps --format json 2>/dev/null | jq -r '.[].name' 2>/dev/null)
            if test -z "$loaded_models"
                set loaded_models (ollama ps 2>/dev/null | awk 'NR>1 {print $1}')
            end
            
            if test -n "$loaded_models"
                for model in $loaded_models
                    if test -n "$model"
                        echo "  Unloading: $model"
                        ollama stop "$model" 2>/dev/null
                    end
                end
                echo "✅ All models unloaded"
            else
                echo "No models were loaded"
            end
            
        case "quantize"
            echo "🗜️  Model Quantization"
            echo
            
            echo "Current models:"
            ollama list
            echo
            
            echo "What would you like to do?"
            echo "  1) Download pre-quantized model (fast)"
            echo "  2) Quantize existing model with llama.cpp (requires llama.cpp)"
            echo
            
            read -P "Select option (1-2): " quant_option
            
            switch $quant_option
                case "1"
                    echo "📥 Download Smaller Model Versions"
                    echo
                    
                    echo "Choose approach:"
                    echo "  1) Popular small models (guaranteed to work)"
                    echo "  2) Try quantized version of your current models"
                    echo
                    
                    read -P "Select approach (1-2): " approach
                    
                    if test "$approach" = "1"
                        # Small models that are known to exist
                        set -l models \
                            "phi3:mini" \
                            "gemma2:2b" \
                            "qwen2.5:3b" \
                            "llama3.2:3b" \
                            "orca-mini:3b" \
                            "tinyllama:1.1b" \
                            "phi3:medium" \
                            "gemma2:9b"
                        
                        echo "Small, fast models:"
                        for i in (seq (count $models))
                            set -l model $models[$i]
                            set -l size_info ""
                            if string match -q "*:1.1b" $model
                                set size_info "~0.6GB - Ultra fast"
                            else if string match -q "*:2b" $model
                                set size_info "~1.4GB - Very fast"  
                            else if string match -q "*:3b" $model
                                set size_info "~2GB - Fast"
                            else if string match -q "*:mini" $model
                                set size_info "~2.3GB - Fast"
                            else if string match -q "*:9b" $model
                                set size_info "~5.5GB - Balanced"
                            else
                                set size_info "~8GB - Better quality"
                            end
                            echo "  $i) $model ($size_info)"
                        end
                        echo
                        
                        read -P "Select model (1-"(count $models)"): " selection
                        if not string match -rq '^[0-9]+$' -- $selection
                            echo "Invalid selection"; return 1
                        end
                        
                        if test $selection -lt 1; or test $selection -gt (count $models)
                            echo "Selection out of range"; return 1
                        end
                        
                        set -l chosen_model $models[$selection]
                        echo "Downloading: $chosen_model"
                        ollama pull "$chosen_model"
                        
                        if test $status -eq 0
                            echo "✅ Successfully downloaded $chosen_model"
                            
                            # Add to models.txt automatically
                            set -l config_dir $HOME/.config/ai
                            set -l models_file $config_dir/models.txt
                            mkdir -p "$config_dir"
                            if not test -f "$models_file"
                                touch "$models_file"
                            end
                            if not grep -q "^$chosen_model\$" "$models_file"
                                echo "$chosen_model" >> "$models_file"
                                echo "✅ Added $chosen_model to your models list"
                            end
                            
                            read -P "Set as default model? (y/N): " set_default
                            if test "$set_default" = "y" -o "$set_default" = "Y"
                                set -Ux MODEL "$chosen_model"
                                echo "✅ Set $chosen_model as default model"
                            end
                        else
                            echo "❌ Failed to download $chosen_model"
                        end
                        
                    else if test "$approach" = "2"
                        echo "Checking your current models for quantized versions..."
                        set -l current_models (ollama list | awk 'NR>1 {print $1}' | grep -v '^$')
                        
                        for model in $current_models
                            echo
                            echo "📦 Checking variants for: $model"
                            
                            # Extract base model name
                            set -l base_model (string split ':' "$model")[1]
                            
                            # Try common quantized tags
                            set -l variants "q4_0" "q5_0" "q8_0" "4bit" "q4" "q5"
                            
                            echo "Trying to find smaller versions..."
                            for variant in $variants
                                set -l test_name "$base_model:$variant"
                                echo -n "  Testing $test_name... "
                                
                                # Quick test if model exists
                                if timeout 5 ollama pull "$test_name" >/dev/null 2>&1
                                    echo "✅ Found! Use: ollama pull $test_name"
                                else
                                    echo "❌"
                                end
                            end
                        end
                        
                        echo
                        echo "💡 Tip: If none found, use approach 1 for guaranteed small models"
                        
                    else
                        echo "Invalid approach"
                        return 1
                    end
                    
                case "2"
                    echo "❌ Custom Quantization Not Supported"
                    echo
                    echo "Unfortunately, Ollama doesn't support easy custom quantization."
                    echo "The process is very complex and involves:"
                    echo "• Extracting model files from Ollama"
                    echo "• Converting to different formats"
                    echo "• Using external tools"
                    echo "• Re-importing to Ollama"
                    echo
                    echo "💡 Recommendation: Use option 1 instead!"
                    echo "Pre-quantized models are:"
                    echo "• Already optimized"
                    echo "• Tested and working"
                    echo "• Much easier to use"
                    echo "• Available immediately"
                    echo
                    read -P "Go back to download pre-quantized models? (y/N): " go_back
                    if test "$go_back" = "y" -o "$go_back" = "Y"
                        # Recursively call this function with option 1
                        __ai_optimize_execute "quantize"
                        return $status
                    end
                    
                case "*"
                    echo "Invalid option"
            end
            
        case "nvidia"
            echo "🚀 NVIDIA GPU Optimization"
            echo
            
            if not command -q nvidia-smi
                echo "❌ NVIDIA drivers not found"
                return 1
            end
            
            echo "Current GPU status:"
            nvidia-smi --query-gpu=name,persistence_mode,power.management --format=csv,noheader 2>/dev/null
            echo
            
            echo "Optimization options:"
            echo "  1) Enable persistence mode (recommended for AI workloads)"
            echo "  2) Set maximum performance mode"
            echo "  3) Show detailed GPU info"
            echo "  4) Reset to default settings"
            
            read -P "Select option: " gpu_option
            
            switch $gpu_option
                case "1"
                    echo "Enabling persistence mode..."
                    sudo nvidia-smi -pm 1
                    echo "✅ Persistence mode enabled"
                    
                case "2"
                    echo "Setting maximum performance..."
                    if command -q nvidia-settings
                        nvidia-settings -a [gpu:0]/GPUPowerMizerMode=1 2>/dev/null
                        echo "✅ Performance mode set"
                    else
                        echo "nvidia-settings not available"
                        echo "Install nvidia-utils for GUI control"
                    end
                    
                case "3"
                    echo "Detailed GPU information:"
                    nvidia-smi -q 2>/dev/null
                    
                case "4"
                    echo "Resetting to defaults..."
                    sudo nvidia-smi -pm 0
                    if command -q nvidia-settings
                        nvidia-settings -a [gpu:0]/GPUPowerMizerMode=0 2>/dev/null
                    end
                    echo "✅ Reset complete"
                    
                case "*"
                    echo "Invalid option"
            end
            
        case "memory"
            echo "💭 Memory Usage Analysis"
            echo
            
            echo "System Memory:"
            free -h
            echo
            
            echo "Ollama Process Memory:"
            ps aux | grep ollama | grep -v grep
            echo
            
            echo "Memory Optimization Tips:"
            echo "• Unload unused models: ai optimize unload"
            echo "• Use smaller quantized models (Q4, Q5)"
            echo "• Close other heavy applications"
            echo "• Consider adding swap if RAM is limited"
            echo "• Monitor with: watch -n 1 'free -h'"
            
        case "cleanup"
            echo "🧹 Cleaning up model files..."
            echo
            
            echo "Checking for temporary files..."
            set -l ollama_dir $HOME/.ollama
            if test -d "$ollama_dir"
                echo "Ollama directory: $ollama_dir"
                echo "Total size: "(du -sh "$ollama_dir" 2>/dev/null | awk '{print $1}')
                echo
                
                echo "Models stored:"
                ollama list
                echo
                
                read -P "Remove unused model blobs? (y/N): " cleanup_confirm
                if test "$cleanup_confirm" = "y" -o "$cleanup_confirm" = "Y"
                    echo "This would require manual cleanup of ~/.ollama/models/"
                    echo "Currently, ollama doesn't have an automated cleanup command"
                    echo "You can manually remove unused model files from:"
                    echo "  $ollama_dir/models/blobs/"
                    echo "But be careful not to remove models you still need!"
                end
            else
                echo "Ollama directory not found"
            end
            
        case "*"
            echo "Unknown command: $argv[1]"
            echo "Use 'ai optimize' to see available commands"
            return 1
    end
end
