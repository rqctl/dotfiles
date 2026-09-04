## ----- Helpers -----
_confirm() {
    local prompt="$1" response
    printf "%s (y/N): " "$prompt"
    read -r response
    [[ "$response" == [Yy]* ]]
}
