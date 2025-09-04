# Rules management implementation

function ai_rules
    set -l config_dir $HOME/.config/ai
    set -l rules_file $config_dir/rules.txt
    set -l templates_dir $config_dir/rules.d
    mkdir -p $templates_dir
    set -l mode "pick"
    if test (count $argv) -ge 1
        set mode $argv[1]
    end
    if test "$mode" = "edit"
        # Picker to edit, create, or delete templates
        set -l options "[New template]" "[Delete template]" (command ls -1 $templates_dir 2>/dev/null)
        echo "Edit rules templates:"
        for i in (seq (count $options))
            echo "  $i) $options[$i]"
        end
        read -P "Select: " sel
        if string match -rq '^[0-9]+$' -- $sel
            if test $sel -lt 1; or test $sel -gt (count $options)
                echo "Selection out of range"; return 1
            end
            set choice $options[$sel]
        else
            if contains -- $sel $options
                set choice $sel
            else
                echo "Invalid choice"; return 1
            end
        end
        if test "$choice" = "[New template]"
            read -P "New template name (e.g., myrules.txt): " tname
            set tname (string trim -- $tname)
            if test -z "$tname"; echo "Name required"; return 1; end
            if not string match -rq '^[A-Za-z0-9._-]+(\\.txt)?$' -- $tname
                echo "Invalid name: use letters, numbers, ., _, -"; return 1
            end
            if not string match -rq '\\.txt$' -- $tname
                set tname "$tname.txt"
            end
            set tfile "$templates_dir/$tname"
            printf "\n" > $tfile
            __ai_open_in_editor $tfile
            read -P "Set as active rules now? (y/N): " yn
            set yn (string lower (string trim -- $yn))
            if test "$yn" = y; or test "$yn" = yes
                cp "$tfile" "$rules_file"
                echo "Active rules set to: $tname"
            end
            return 0
        else if test "$choice" = "[Delete template]"
            set -l to_delete (command ls -1 $templates_dir 2>/dev/null)
            if test -z "$to_delete"
                echo "No templates to delete"; return 0
            end
            echo "Choose template to delete:"
            for i in (seq (count $to_delete))
                echo "  $i) $to_delete[$i]"
            end
            read -P "Select: " del_sel
            if string match -rq '^[0-9]+$' -- $del_sel
                if test $del_sel -lt 1; or test $del_sel -gt (count $to_delete)
                    echo "Selection out of range"; return 1
                end
                set del_choice $to_delete[$del_sel]
            else
                if contains -- $del_sel $to_delete
                    set del_choice $del_sel
                else
                    echo "Invalid choice"; return 1
                end
            end
            read -P "Type DELETE to confirm removing $del_choice: " confirm
            if test "$confirm" != "DELETE"
                echo "Cancelled"; return 1
            end
            rm -f "$templates_dir/$del_choice"
            echo "Deleted: $del_choice"
            return 0
        else
            set tfile "$templates_dir/$choice"
            if not test -f "$tfile"
                echo "Not found: $choice"; return 1
            end
            __ai_open_in_editor $tfile
            read -P "Set as active rules now? (y/N): " yn
            set yn (string lower (string trim -- $yn))
            if test "$yn" = y; or test "$yn" = yes
                cp "$tfile" "$rules_file"
                echo "Active rules set to: $choice"
            end
            return 0
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
                echo "Selection out of range"; return 1
            end
            set choice $options[$sel]
        else
            if contains -- $sel $options
                set choice $sel
            else
                echo "Invalid choice"; return 1
            end
        end
        if test "$choice" = "[New template]"
            read -P "New template name (e.g., myrules.txt): " tname
            set tname (string trim -- $tname)
            if test -z "$tname"; echo "Name required"; return 1; end
            if not string match -rq '^[A-Za-z0-9._-]+(\\.txt)?$' -- $tname
                echo "Invalid name: use letters, numbers, ., _, -"; return 1
            end
            if not string match -rq '\\.txt$' -- $tname
                set tname "$tname.txt"
            end
            set tfile "$templates_dir/$tname"
            printf "\n" > $tfile
            __ai_open_in_editor $tfile
            cp "$tfile" "$rules_file"
            echo "Active rules set to: $tname"
            return 0
        else
            set tfile "$templates_dir/$choice"
            if not test -f "$tfile"
                echo "Not found: $choice"; return 1
            end
            cp "$tfile" "$rules_file"
            echo "Active rules set to: $choice"
            return 0
        end
    end
end
