#!/usr/bin/env fish
if not set -q MODEL
set MODEL "qwen2.5:7b-instruct"
end

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

if test (count $argv) -eq 0
    echo "Usage: ai \"your prompt\"  |  ai help"
    exit 1
end

if test "$argv[1]" = "help"
    echo "ai - simple Ollama helper"
    echo
    echo "Commands:"
    echo "  ai \"prompt\"        Run a prompt with the current MODEL"
    echo "  ai model          Pick a default model (pulls if needed)"
    echo "  ai setup          Interactive setup (editor, GPU/CPU, rules templates)"
    echo "  ai rules          Pick a rules template to activate"
    echo "  ai rules edit     Edit/create rules templates via your editor"
    echo "  ai help           Show this help"
    echo
    echo "Config files:"
    echo "  ~/.config/ai/models.txt     Candidate model tags"
    echo "  ~/.config/ai/rules.txt      Active rules (prepended to prompts)"
    echo "  ~/.config/ai/rules.d/*      Rules templates"
    echo
    echo "Env vars:"
    echo "  MODEL               Default model tag (e.g., qwen2.5:7b-instruct)"
    echo "  AI_EDITOR           Preferred editor for templates"
    echo "  OLLAMA_NO_GPU=1     Force CPU (unset to prefer GPU)"
    echo
    echo "Examples:"
    echo "  ai \"explain this code\""
    echo "  ai model qwen2.5:14b-instruct"
    echo "  ai rules            # choose a template"
    echo "  ai rules edit       # edit or create a template"
    exit 0
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

if test "$argv[1]" = "setup"
    set -l config_dir $HOME/.config/ai
    set -l models_file $config_dir/models.txt
    set -l rules_file $config_dir/rules.txt
    set -l templates_dir $config_dir/rules.d
    mkdir -p $config_dir $templates_dir

    if not test -f $models_file
        printf "%s\n" \
            "qwen2.5:7b-instruct" \
            "llama3.1:8b-instruct" \
            "qwen2.5:14b-instruct" \
            "mixtral:8x7b-instruct" \
            "qwen2.5:32b-instruct" > $models_file
    end

    # Seed default rule templates
    if not test -f $templates_dir/concise.txt
        printf "%s\n" \
            "Be concise. Use short, direct answers." \
            "Avoid verbose explanations unless asked." > $templates_dir/concise.txt
    end
    if not test -f $templates_dir/detailed.txt
        printf "%s\n" \
            "Be thorough and structured." \
            "Explain reasoning and provide examples when helpful." > $templates_dir/detailed.txt
    end
    if not test -f $templates_dir/code_helper.txt
        printf "%s\n" \
            "Answer as a coding assistant." \
            "Prefer step-by-step fixes and minimal prose." > $templates_dir/code_helper.txt
    end

    # Choose editor
    echo "Select your preferred editor:"
    set -l editors
    if set -q AI_EDITOR
        set editors $editors $AI_EDITOR
    end
    if set -q EDITOR
        if not contains -- $EDITOR $editors
            set editors $editors $EDITOR
        end
    end
    for e in nano nvim vim vi
        if type -q $e
            if not contains -- $e $editors
                set editors $editors $e
            end
        end
    end
    if test (count $editors) -eq 0
        set editors vi
    end
    for i in (seq (count $editors))
        echo "  $i) $editors[$i]"
    end
    read -P "Editor number: " ed_sel
    if string match -rq '^[0-9]+$' -- $ed_sel
        if test $ed_sel -ge 1; and test $ed_sel -le (count $editors)
            set -Ux AI_EDITOR $editors[$ed_sel]
        end
    else
        if contains -- $ed_sel $editors
            set -Ux AI_EDITOR $ed_sel
        else
            set -Ux AI_EDITOR $editors[1]
        end
    end

    # GPU or CPU default
    read -P "Use GPU when available? (Y/n): " gpu_ans
    set gpu_ans (string lower (string trim -- $gpu_ans))
    if test -z "$gpu_ans"; or test "$gpu_ans" = y; or test "$gpu_ans" = yes
        set -eU OLLAMA_NO_GPU 2>/dev/null
    else
        set -Ux OLLAMA_NO_GPU 1
    end

    # Ensure an active rules file exists; pick a template
    echo "Select a default rules template:"
    set -l templates (command ls -1 $templates_dir 2>/dev/null)
    if test -z "$templates"
        set templates concise.txt
    end
    for i in (seq (count $templates))
        echo "  $i) $templates[$i]"
    end
    read -P "Template number: " t_sel
    if string match -rq '^[0-9]+$' -- $t_sel
        if test $t_sel -ge 1; and test $t_sel -le (count $templates)
            cp $templates_dir/$templates[$t_sel] $rules_file
        end
    else
        if test -f $templates_dir/$t_sel
            cp $templates_dir/$t_sel $rules_file
        else
            cp $templates_dir/concise.txt $rules_file
        end
    end

    # Preserve current MODEL as universal default
    set -Ux MODEL $MODEL
    echo "Setup complete. Config in $config_dir"
    echo "- models: $models_file"
    echo "- rules:  $rules_file (from rules.d)"
    echo "- editor: $AI_EDITOR"
    echo "- GPU default: "(test -n "$OLLAMA_NO_GPU"; and echo CPU; or echo GPU)
    exit 0
end

if test "$argv[1]" = "rules"
    set -l config_dir $HOME/.config/ai
    set -l rules_file $config_dir/rules.txt
    set -l templates_dir $config_dir/rules.d
    mkdir -p $templates_dir
    set -l mode "pick"
    if test (count $argv) -ge 2
        set mode $argv[2]
    end
    if test "$mode" = "edit"
        # Picker to edit or create templates
        set -l options "[New template]" (command ls -1 $templates_dir 2>/dev/null)
        echo "Edit rules templates:"
        for i in (seq (count $options))
            echo "  $i) $options[$i]"
        end
        read -P "Select: " sel
        if string match -rq '^[0-9]+$' -- $sel
            if test $sel -lt 1; or test $sel -gt (count $options)
                echo "Selection out of range"; exit 1
            end
            set choice $options[$sel]
        else
            set choice $sel
        end
        if test "$choice" = "[New template]"
            read -P "New template name (e.g., myrules.txt): " tname
            set tname (string trim -- $tname)
            if test -z "$tname"; echo "Name required"; exit 1; end
            if not string match -rq '\\.txt$' -- $tname
                set tname "$tname.txt"
            end
            set tfile $templates_dir/$tname
            printf "\n" > $tfile
            __ai_open_in_editor $tfile
            read -P "Set as active rules now? (y/N): " yn
            set yn (string lower (string trim -- $yn))
            if test "$yn" = y; or test "$yn" = yes
                cp $tfile $rules_file
                echo "Active rules set to: $tname"
            end
            exit 0
        else
            set tfile $templates_dir/$choice
            if not test -f $tfile
                echo "Not found: $choice"; exit 1
            end
            __ai_open_in_editor $tfile
            read -P "Set as active rules now? (y/N): " yn
            set yn (string lower (string trim -- $yn))
            if test "$yn" = y; or test "$yn" = yes
                cp $tfile $rules_file
                echo "Active rules set to: $choice"
            end
            exit 0
        end
    else
        # Pick a template to activate
        set -l options (command ls -1 $templates_dir 2>/dev/null)
        set options "[New template]" $options
        echo "Choose rules template:"
        for i in (seq (count $options))
            echo "  $i) $options[$i]"
        end
        read -P "Select: " sel
        if string match -rq '^[0-9]+$' -- $sel
            if test $sel -lt 1; or test $sel -gt (count $options)
                echo "Selection out of range"; exit 1
            end
            set choice $options[$sel]
        else
            set choice $sel
        end
        if test "$choice" = "[New template]"
            read -P "New template name (e.g., myrules.txt): " tname
            set tname (string trim -- $tname)
            if test -z "$tname"; echo "Name required"; exit 1; end
            if not string match -rq '\\.txt$' -- $tname
                set tname "$tname.txt"
            end
            set tfile $templates_dir/$tname
            printf "\n" > $tfile
            __ai_open_in_editor $tfile
            cp $tfile $rules_file
            echo "Active rules set to: $tname"
            exit 0
        else
            set tfile $templates_dir/$choice
            if not test -f $tfile
                echo "Not found: $choice"; exit 1
            end
            cp $tfile $rules_file
            echo "Active rules set to: $choice"
            exit 0
        end
    end
end

if test "$argv[1]" = "rule"
    echo "'ai rule' is deprecated. Use 'ai rules' or 'ai rules edit'."
    exit 1
end

if test "$argv[1]" = "model"
    if test (count $argv) -ge 2
        set -l new_model $argv[2]
        set -l installed (ollama list | awk 'NR>1 {print $1}')
        set -l target $new_model
        if not contains -- $target $installed
            echo "Pulling $target ..."
            ollama pull $target
            if test $status -ne 0
                set -l alt (string replace -a "-instruct" "" -- $target)
                if test "$alt" != "$target"
                    echo "Pull failed, trying $alt ..."
                    ollama pull $alt
                    if test $status -eq 0
                        set target $alt
                    end
                end
                if test "$target" = "$new_model"
                    set -l base (string split -m 1 ':' -- $target)[1]
                    if test -n "$base"
                        echo "Pull failed, trying $base ..."
                        ollama pull $base
                        if test $status -eq 0
                            set target $base
                        end
                    end
                end
                if test "$target" = "$new_model"
                    echo "Failed to pull $new_model. Edit ~/.config/ai/models.txt with a valid tag."
                    exit 1
                end
            end
        end
        set -Ux MODEL $target
        set -g MODEL $target
        echo "Default model set to: $target"
        exit 0
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
        exit 1
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
            exit 1
        end
        # If numeric, pick by index
        if string match -rq '^[0-9]+$' -- $selection
            if test $selection -lt 1; or test $selection -gt (count $candidates)
                echo "Selection out of range"
                exit 1
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
                exit 1
            end
        end
    end

    set -l installed (ollama list | awk 'NR>1 {print $1}')
    set -l target $chosen
    if not contains -- $target $installed
        echo "Pulling $target ..."
        ollama pull $target
        if test $status -ne 0
            set -l alt (string replace -a "-instruct" "" -- $target)
            if test "$alt" != "$target"
                echo "Pull failed, trying $alt ..."
                ollama pull $alt
                if test $status -eq 0
                    set target $alt
                end
            end
            if test "$target" = "$chosen"
                set -l base (string split -m 1 ':' -- $target)[1]
                if test -n "$base"
                    echo "Pull failed, trying $base ..."
                    ollama pull $base
                    if test $status -eq 0
                        set target $base
                    end
                end
            end
            if test "$target" = "$chosen"
                echo "Failed to pull $chosen. Edit ~/.config/ai/models.txt with a valid tag."
                exit 1
            end
        end
    end

    set -Ux MODEL $target
    set -g MODEL $target
    echo "Default model set to: $target"
    exit 0
end

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

