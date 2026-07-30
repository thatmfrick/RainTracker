fatal() {
    tput setaf 1
    echo "[error]" "$@" >&2
    tput sgr0
    exit
}

create_pipe() {
    local KB_PIPE=/tmp/kb_raintracker.$$
    mkfifo "$KB_PIPE" || fatal "failed to create pipes"
    exec 3<>"$KB_PIPE" || fatal "failed to open pipes"
    rm "$KB_PIPE"
}

cleanup() {
    pkill -P $$
    tput cnorm
    tput rmcup
    stty echo 2>/dev/null
}

connection_status() {
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

setup() {
    tput civis
    tput smcup
    stty -echo
    exec 4</dev/tty || fatal 'no terminal detected'
    create_pipe
    # connection_status
    draw_logo
    draw_menu
    tput cup $(((LINES - 17) / 2)) $((COLUMNS / 2 - 82 / 2))
    chafa --polite on --probe off assets/madcat.jpeg
}

keyboard_input() {
    local escape_char=$'\x1b'
    while true; do
        local data=
        read -rsn1 data 2>/dev/null || return
        if [[ $data == "$escape_char" ]]; then
            read -rsn2 data 2>/dev/null || return
        fi

        local output=
        case "$data" in
        q) output='key-quit' ;;
        f) output='key-change-file' ;;
        z) output='key-change-zoom' ;;
        d) output='key-donate' ;;
        esac

        if [[ -n $output ]]; then
            echo "$output" >&3
        fi
    done
}

kill_handler() {
    local PID="$1"
    kill "$PID" 2>/dev/null
    pkill -P "$PID" 2>/dev/null
    wait "$PID" 2>/dev/null
}

event_handler() {
    local kb_pid data_pid
    local shape csv_file location
    local api_zoom virtual_zoom crop_size crop_x crop_y
    local zoom_value

    keyboard_input <&4 &
    kb_pid=$!

    echo 'key-change-file' >&3

    while true; do
        if IFS='|' read -ra data -t 1 <&3; then
            local event=${data[0]}
            case "$event" in
            key-quit) exit ;;
            key-donate) xdg-open "$KOFI" 2>/dev/null & ;;
            key-change-file)
                kill_handler "$data_pid"
                get_shape "$kb_pid"
                echo 'key-change-zoom' >&3
                ;;
            key-change-zoom)
                kill_handler "$data_pid"
                zoom_select "$kb_pid"
                ;;
            selected-shape)
                shape=${data[1]}
                csv_file=${data[2]}
                location=${data[3]}
                ;;
            selected-zoom)
                zoom_value=${data[1]}
                read -r api_zoom virtual_zoom crop_size crop_x crop_y <<<"$(zoom_calculi "$zoom_value")"
                generate_data "$api_zoom" "$virtual_zoom" "$shape" "$crop_size" "$crop_x" "$crop_y" "$csv_file" "$location" &
                data_pid=$!
                ;;
            esac
        fi
    done
}
