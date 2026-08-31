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

    local crop_size crop_L crop_T
    read -r crop_size crop_L crop_T <<<"$(awk -f lib/math.awk -v zoom="$virtual_zoom" -v pic_size="$PICTURE_SIZE" -e 'BEGIN { print zoom_calculi(zoom, pic_size ) }')"

    local image_path
    image_path="$(jq -r '.host + .radar.past[-1].path' <<<"$response")"

    local radar_pic
    radar_pic="$CACHE_DIR/$(jq -r '.radar.past.[-1].time' <<<"$response")_${c_lat}_${c_lon}_${api_zoom}.png"

    local tmpdir
    tmpdir=$(mktemp -d)

    local tile_x tile_y offset_L offset_T
    read -r tile_x tile_y offset_L offset_T <<<"$(awk -f lib/math.awk -v lat="$c_lat" -v lon="$c_lon" -v zoom="$api_zoom" -e 'BEGIN { print latlon_to_tile(lat, lon, zoom) }')"

    local i=0 tx ty
    if [[ ! -f "$radar_pic" ]]; then
        for y in -1 0 1; do
            for x in -1 0 1; do
                tx=$((tile_x + x))
                ty=$((tile_y + y))
                curl -sf "$image_path/$((PICTURE_SIZE / 2))/$api_zoom/$tx/$ty/1/1_1.png" -o "$tmpdir/tile_${i}.png" &
                ((i++))
            done
        done
        wait

        magick "$tmpdir/tile_0.png" "$tmpdir/tile_1.png" "$tmpdir/tile_2.png" +append \
            \( "$tmpdir/tile_3.png" "$tmpdir/tile_4.png" "$tmpdir/tile_5.png" +append \) \
            \( "$tmpdir/tile_6.png" "$tmpdir/tile_7.png" "$tmpdir/tile_8.png" +append \) \
            -append \
            -crop "${PICTURE_SIZE}x${PICTURE_SIZE}+${offset_L}+${offset_T}" +repage \
            -filter point \
            "$RAINVIEWER_PIC" 2>/dev/null
        cp "$RAINVIEWER_PIC" "$radar_pic"
        rm -rf "$tmpdir"
    else
        magick "$radar_pic" "$RAINVIEWER_PIC" 2>/dev/null
    fi

    magick "$RAINVIEWER_PIC" \
        -crop "${crop_size}x${crop_size}+${crop_L}+${crop_T}" +repage \
        -filter point \
        -resize "${PICTURE_SIZE}x${PICTURE_SIZE}" \
        "$CROPPED_RADAR_PIC" 2>/dev/null

}
