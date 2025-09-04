#!/usr/bin/env fish
if not set -q MODEL
    set MODEL "qwen2.5:7b-instruct"
end

if test (count $argv) -eq 0
    echo "Usage: ai \"your prompt\""
    exit 1
end

set -l prompt (string join " " -- $argv)
ollama run $MODEL "$prompt"

