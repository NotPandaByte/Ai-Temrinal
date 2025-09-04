# Help command implementation

function ai_help
    echo "ai - simple Ollama helper"
    echo
    echo "Commands:"
    echo "  ai \"prompt\"      Run a prompt with the current MODEL"
    echo "  ai model          Pick a default model (pulls if needed)"
    echo "  ai setup          Interactive setup (editor, GPU/CPU, rules templates)"
    echo "  ai rules          Pick a rules template to activate"
    echo "  ai rules edit     Edit/create rules templates via your editor"
    echo "  ai do \"task\"     Plan and run safe system tasks (e.g., update)"
    echo "  ai agent \"task\"  AI-planned commands using system context (confirm to run)"
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
end
