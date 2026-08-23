radar_sleep_time() {
    local response="$1"

    local time_diff
    local minutes_sleep seconds_sleep

    time_diff=$(jq -r '.generated - .radar.past.[-1].time' <<<"$response")

    minutes_sleep=$((9 - (time_diff / 60)))
    seconds_sleep=$((60 - (time_diff % 60)))

    echo "${minutes_sleep}m" "${seconds_sleep}s"
}

last_radar_time() {
    local response="$1"
    local current_radar_time
    current_radar_time=$(jq -r '.radar.past.[-1].time' <<<"$response")
    echo "$current_radar_time"
}

generate_radar_pic() {
    local c_lat="$1" c_lon="$2"
    local api_zoom="$3" virtual_zoom="$4"
    local response="$5"

    local image_path

    image_path="$(jq -r '.host + .radar.past[-1].path' <<<"$response")"

    local crop_size crop_L crop_T

    read -r crop_size crop_L crop_T <<<"$(zoom_calculi "$virtual_zoom")"

    curl -sf "$image_path/$PICTURE_SIZE/$api_zoom/$c_lat/$c_lon/1/1_1.png" -o "$RAINVIEWER_PIC" &
    wait

    magick "$RAINVIEWER_PIC" \
        -crop "${crop_size}x${crop_size}+${crop_L}+${crop_T}" +repage \
        -filter point \
        -resize "${PICTURE_SIZE}x${PICTURE_SIZE}" \
        "$CROPPED_RADAR_PIC" 2>/dev/null
}
