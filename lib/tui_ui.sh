clean_area() {
    local area_lines="$1" area_rows="$2"
    local starting_point_l="$3" starting_point_r="$4"
    local i
    while ((i < area_lines)); do
        tput cup "$((starting_point_l + i))" "$starting_point_r"
        printf "%${area_rows}s" ''
        ((i++))
    done
}

draw_logo() {
    local x y

    x=$(((COLUMNS - LOGO_L) / 2))
    y=$((LOGO_H + 1))

    tput cup "$y" "$x"
    chafa --polite on --probe off assets/ascii-art-text.png
}

draw_menu() {
    local x y

    x=$(((COLUMNS - MENU_L) / 2))
    y=$((LINES - MENU_H * 6))

    tput cup "$y" "$x"
    printf %s "$MENU_LIST"
}

file_prompt() {
    local i
    local files=()

    files=("config/"*)

    # File Prompt
    tput cup $((LOGO_H * 3)) $(((COLUMNS - FILE_PROMPT_L - 1) / 2))
    printf '%s' "$FILE_PROMPT"

    #lines from file prompt to menu line
    for i in "${!files[@]}"; do
        tput cup $((LOGO_H * 4 + i)) $(((COLUMNS - FILE_PROMPT_L) / 2))
        printf "%s%s\n" "${SOFT_BLUE}$i${RESET}. " "${files[$i]}"
    done
}

# to-do -> implement a better file_prompt
