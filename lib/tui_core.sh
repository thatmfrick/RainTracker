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

draw_ui() {
    draw_logo
    draw_menu
}

setup() {
    tput civis
    tput smcup
    stty -echo
    exec 4</dev/tty || fatal 'no terminal detected'
    create_pipe
    check_connection_status
    echo draw >&3
}

resizing() {
    local cols=$1 lines=$2

    tput clear

    ((cols < MIN_COLS)) && COLS_COLOR="${RED}$cols${RESET}" || COLS_COLOR="${GREEN}$cols${RESET}"
    ((lines < MIN_LINES)) && LINES_COLOR="${RED}$lines${RESET}" || LINES_COLOR="${GREEN}$lines${RESET}"

    if ((cols >= 30)) && ((lines >= 9)); then

        tput cup $(((lines - 4) / 2)) $(((cols - 24) / 2))
        printf %s 'Terminal size too small:'

        tput cup $(((lines - 2) / 2)) $(((cols - 22) / 2))
        echo -e "Width = ${COLS_COLOR} Height = ${LINES_COLOR}"

        tput cup $(((lines + 2) / 2)) $(((cols - 26) / 2))
        echo -e "Needed for current config:"

        tput cup $(((lines + 4) / 2)) $(((cols - 22) / 2))
        echo -e "Width = $MIN_COLS Height = $MIN_LINES"
    fi
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
        'w' | 'W' | '[A') output='key-zoom-in' ;;
        's' | 'S' | '[B') output='key-zoom-out' ;;
        'a' | 'A' | '[D') output='key-file-prev' ;;
        'd' | 'D' | '[C') output='key-file-next' ;;
        '') output='key-enter' ;;
        q) output='key-quit' ;;
        k) output='key-donate' ;;
        esac

        if [[ -n $output ]]; then
            echo "$output" >&3
        fi
    done
}

kill_handler() {
    for item in "$@"; do
        kill "$item" 2>/dev/null
        pkill -P "$item" 2>/dev/null
        wait "$item" 2>/dev/null
    done
}

event_handler() {
    local csv_file
    local api_zoom virtual_zoom
    local file_index=0 zoom=9 debounce=0
    local data_pid resize_pid open_meteo_pid debounce_pid

    while true; do
        if IFS='|' read -ra data -t 1 <&3 && [[ ! -f "$BUSY_LOCK" ]]; then
            local event=${data[0]}
            case "$event" in
            key-quit) exit ;;
            key-donate) xdg-open "$KOFI" 2>/dev/null & ;;
            key-start)
                draw_ui
                check_file_index "$file_index"
                check_zoom "$zoom"
                ;;
            key-zoom-in)
                kill_handler "$data_pid"
                ((zoom++))
                check_zoom "$zoom"
                ;;
            key-zoom-out)
                kill_handler "$data_pid"
                ((zoom--))
                check_zoom "$zoom"
                ;;
            key-file-next)
                kill_handler "$data_pid" "$open_meteo_pid" "$debounce_pid"
                ((file_index++))
                check_file_index "$file_index"
                ;;
            key-file-prev)
                kill_handler "$data_pid" "$open_meteo_pid" "$debounce_pid"
                ((file_index--))
                check_file_index "$file_index"
                ;;
            selected-file)
                csv_file=${data[1]}
                file_index=${data[2]}
                print_location "$csv_file"
                debounce=0.5
                sleep $debounce &
                debounce_pid=$!
                trap 'kill "$debounce_pid" 2>/dev/null' USR1
                wait "$debounce_pid" 2>/dev/null
                debounce_status=$?
                trap - USR1

                if ((debounce_status != 0)); then
                    continue
                fi

                generate_weather_data "$csv_file" &
                open_meteo_pid=$!
                check_zoom "$zoom"
                ;;
            selected-zoom)
                zoom=${data[1]}
                api_zoom=${data[2]}
                virtual_zoom=${data[3]}

                touch "$BUSY_LOCK"
                core_fun "$api_zoom" "$virtual_zoom" "$csv_file" &
                data_pid=$!
                ;;
            resize)
                kill_handler "$data_pid"
                kill_handler "$open_meteo_pid"
                resizing "$(tput cols)" "$(tput lines)"
                kill_handler "$resize_pid"
                (
                    sleep 0.3
                    echo "draw" >&3
                ) &
                resize_pid=$!
                ;;
            draw)
                if (($(tput cols) >= MIN_COLS)) && (($(tput lines) >= MIN_LINES)); then
                    echo 'key-start' >&3
                else
                    resizing "$(tput cols)" "$(tput lines)"
                fi
                ;;
            esac
        fi
    done
}
