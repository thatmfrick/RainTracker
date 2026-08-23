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

check_zoom() {
    local zoom="$1"

    if ((zoom > 17)); then
        zoom=17
    elif ((zoom < 0)); then
        zoom=0
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

    mkdir "$CSV_FOLDER" 2>/dev/null
    if [ -z "$(ls -A "$CSV_FOLDER" 2>/dev/null)" ]; then
        fatal 'No files to source'
    fi

    files=("$CSV_FOLDER"/*)
    max_position=$((${#files[@]} - 1))

    if ((cursor_index > max_position)); then
        cursor_index=0
    elif ((cursor_index < 0)); then
        cursor_index=$max_position
    fi

    echo "selected-file|${files[$cursor_index]}|$cursor_index" >&3
}
