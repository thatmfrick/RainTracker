clean_area() {
    local starting_line="$1" starting_row="$2"
    local area_lines="$3" area_rows="$4"
    local i=0
    while ((i < area_lines)); do
        tput cup "$((starting_line + i))" "$starting_row"
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

print_qrcode() {
    local i=0

    while IFS= read -r line; do
        tput cup "$(((LINES - QR_CODE_H) / 2 + i))" "$(((COLUMNS - QR_CODE_L) / 2))"
        printf '%s' "$line"
        ((i++))
    done <<<"$QR_CODE_ASCII"
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

print_location() {
    local selected_file="$1"
    local half_logo
    local location location_len

    IFS='|' read -r location location_len <<<"$(detect_location "$selected_file")"
    location_len=$((location_len + 4))

    half_logo=$(((COLUMNS - LOGO_L) / 2 + (LOGO_L - location_len) / 2))

    clean_area $(((LINES - PIC_H) / 2)) 1 1 $COLUMNS

    tput cup $(((LINES - PIC_H) / 2)) $half_logo
    echo "⬅️ $location ➡️"
}

print_radar() {
    magick -size "${PICTURE_SIZE}x${PICTURE_SIZE}" \
        xc:none "$MAP_PIC" -composite \
        "$CROPPED_RADAR_PIC" -compose dissolve -define compose:args=80 -composite \
        -compose over "$POLYGON_BORDER_PIC" -composite \
        assets/NESW.png -composite \
        "$COMPOSITE_PIC" 2>/dev/null

    magick "$COMPOSITE_PIC" \
        \( -size 512x512 xc:black -fill white -draw "circle 255,255 255,0" \) \
        -alpha off -compose CopyOpacity -composite \
        "$FINAL_PIC"

    tput cup $(((LINES - PIC_H) / 2 + 2)) $(((COLUMNS - LOGO_L) / 2))
    chafa --polite on --probe off "$FINAL_PIC"
}
