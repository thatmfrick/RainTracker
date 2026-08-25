check_connection_status() {
    local attempts=0
    local max_attempts=5
    until curl -sf --max-time 5 "$RAINVIEWER_API" &>/dev/null; do
        ((attempts++))
        if ((attempts >= max_attempts)); then
            fatal "No connection"
        fi
        sleep 2
    done
}

check_file_directory() {
    mkdir "$CSV_FOLDER" 2>/dev/null
    if [ -z "$(ls -A "$CSV_FOLDER" 2>/dev/null)" ]; then
        tput cup $(((LINES - PIC_H) / 2 + 2)) $(((COLUMNS - PIC_L) / 2))

        print_qrcode
        inotifywait -e create -e moved_to "$CSV_FOLDER" >/dev/null 2>&1
        #kernel level (avoids wasted cpu cycles + instant) requires inotify-tools
        clean_area "$(((LINES - QR_CODE_H) / 2))" "$(((COLUMNS - QR_CODE_L) / 2))" "$QR_CODE_H" "$QR_CODE_L"
    fi
}

check_zoom() {
    local zoom="$1"

    if ((zoom > 17)); then
        zoom=17
    elif ((zoom < 2)); then
        zoom=2
    fi

    if ((zoom > 7)); then
        api_zoom=7
        virtual_zoom=$((zoom - 7))
    elif ((zoom <= 7)); then
        api_zoom=$zoom
        virtual_zoom=0
    fi

    echo "selected-zoom|$zoom|$api_zoom|$virtual_zoom" >&3
}

check_file_index() {
    local cursor_index="$1"
    local files=()

    files=("$CSV_FOLDER"/*)
    max_position=$((${#files[@]} - 1))

    if ((cursor_index > max_position)); then
        cursor_index=0
    elif ((cursor_index < 0)); then
        cursor_index=$max_position
    fi

    echo "selected-file|${files[$cursor_index]}|$cursor_index" >&3
}
