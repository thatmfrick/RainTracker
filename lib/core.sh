#!/usr/bin/env bash

fetch_data() {
    local RAINVIEWER_API='https://api.rainviewer.com/public/weather-maps.json' HOST TIME IMAGE_PATH
    while true; do
        RESPONSE=$(curl -sf "$RAINVIEWER_API")
        TIME=$(date --date "@$(jq -r '.radar.past[-1].time' <<<"$RESPONSE")" +%M)
        HOST=$(jq -r '.host' <<<"$RESPONSE")
        IMAGE_PATH=$(jq -r '.radar.past[-1].path' <<<"$RESPONSE")
        build_image_url "$HOST" "$IMAGE_PATH"
        sleep 60
    done
}

#Test location (Bolzan) middle of the pic

build_image_url() {
    local HOST="$1" IMAGE_PATH="$2" TEMP_PATH FULL_PATH LAT=46.492531 LON=11.341467
    TEMP_PATH=$(echo "$HOST""$IMAGE_PATH" | sed 's/"//g')
    FULL_PATH="$TEMP_PATH/2048/7/$LAT/$LON/0/1_1.png"
    curl -s "$FULL_PATH" | chafa --clear
}
