# Setup command implementation

function ai_setup
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
            set -Ux AI_EDITOR "$editors[$ed_sel]"
        end
    else
        if contains -- $ed_sel $editors
            set -Ux AI_EDITOR "$ed_sel"
        else
            set -Ux AI_EDITOR "$editors[1]"
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
            cp "$templates_dir/$templates[$t_sel]" "$rules_file"
        end
    else
        if contains -- $t_sel $templates
            cp "$templates_dir/$t_sel" "$rules_file"
        else
            cp "$templates_dir/concise.txt" "$rules_file"
        end
    end

    # Preserve current MODEL as universal default
    set -Ux MODEL $MODEL
    echo "Setup complete. Config in $config_dir"
    echo "- models: $models_file"
    echo "- rules:  $rules_file (from rules.d)"
    echo "- editor: $AI_EDITOR"
    echo "- GPU default: "(test -n "$OLLAMA_NO_GPU"; and echo CPU; or echo GPU)
end
