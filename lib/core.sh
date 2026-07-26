fatal() {
    tput setaf 1
    echo "[error]" "$@" >&2
    tput sgr0
    exit 1
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

setup() {
    tput civis
    tput smcup
    stty -echo
    exec 4</dev/tty || fatal 'no terminal detected'
    create_pipe
    draw_logo
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
        esac

        if [[ -n $output ]]; then
            echo "$output" >&3
        fi
    done
}

event_handler() {
    local KB_PID
    local shape csv_file
    keyboard_input <&4 &
    KB_PID=$!
    echo "choose-shape" >&3
    while true; do
        if read -ra data -t 1 <&3; then
            local event=${data[0]}
            case "$event" in
            key-quit) exit ;;
            selected-shape)
                shape=${data[1]}
                csv_file=${data[2]}
                select_options "$KB_PID" "$shape" "$csv_file"
                ;;
            choose-shape)
                kill -TSTP $KB_PID
                get_shape
                ;;
            esac
        fi
    done
}
