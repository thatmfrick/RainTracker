#!/usr/bin/env bash

fetch_data() {
    local LAT="$1" LON="$2" RAINVIEWER_API='https://api.rainviewer.com/public/weather-maps.json' HOST TIME IMAGE_PATH
    while true; do
        RESPONSE=$(curl -sf "$RAINVIEWER_API")
        TIME=$(date --date "@$(jq -r '.radar.past[-1].time' <<<"$RESPONSE")" +%M)
        HOST=$(jq -r '.host' <<<"$RESPONSE")
        IMAGE_PATH=$(jq -r '.radar.past[-1].path' <<<"$RESPONSE")
        build_image_url "$HOST" "$IMAGE_PATH" "$LAT" "$LON"
        sleep 60
    done
}

build_image_url() {
    local HOST="$1" IMAGE_PATH="$2" LAT="$3" LON="$4" TEMP_PATH FULL_PATH
    TEMP_PATH=$(echo "$HOST""$IMAGE_PATH" | sed 's/"//g')
    FULL_PATH="$TEMP_PATH/512/7/$LAT/$LON/0/1_1.png"

    PIC=$(mktemp --suffix=.png)
    curl -sf "$FULL_PATH" >"$PIC"

    magick "$PIC" -fill none -stroke lime -strokewidth 1 -draw "line 255,256 257,256" -draw "line 256,255 256,257" "$PIC"

    chafa --clear --polite on --probe off "$PIC"
}

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
    local LAT LON
    read -r -p "Insert Latitude: " LAT
    read -r -p "Insert Longitude: " LON
    tput civis
    tput smcup
    stty -echo
    exec 4</dev/tty || fatal 'no terminal detected'
    create_pipe
    fetch_data "$LAT" "$LON" &
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
    while true; do
        if read -ra data -t 1 <&3; then
            local event=${data[0]}
            case "$event" in
            key-quit) exit ;;
            esac
        fi
    done
}
