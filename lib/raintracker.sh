draw_polygon() {
    local c_lat="$1" c_lon="$2"
    local full_zoom="$3" csv_file="$4"

    local c_px c_py
    local polygon=""

    read -r c_px c_py <<<"$(latlon_to_pixel "$c_lat" "$c_lon" "$full_zoom")"
    polygon="$(pixel_coords "$c_px" "$c_py" "$full_zoom" "$csv_file")"

    magick -size "${PICTURE_SIZE}x${PICTURE_SIZE}" xc:none -fill none \
        -stroke black -strokewidth 2 \
        -draw "polygon $polygon" "$POLYGON_BORDER_PIC"
}

calculate_centroid() {
    local csv_file="$1"

    local c_lat c_lon

    if (($(wc -l <"$csv_file") > 2)); then
        read -r c_lat c_lon <<<"$(centroid_radar "$csv_file")"
    else
        fatal "Not enough points"
    fi

    echo "$c_lat" "$c_lon"
}

generate_weather_data() {
    local csv_file="$1"
    while true; do
        openmeteo_data "$csv_file"
        sleep 300
    done
}

core_fun() {
    local api_zoom="$1" virtual_zoom="$2"
    local csv_file="$3"

    local api_response current_pic last_pic
    local poly_pid map_pid

    local full_zoom
    full_zoom=$((api_zoom + virtual_zoom))

    local c_lat c_lon
    read -r c_lat c_lon <<<"$(calculate_centroid "$csv_file")"

    draw_polygon "$c_lat" "$c_lon" "$full_zoom" "$csv_file" &
    poly_pid=$!

    generate_map "$c_lat" "$c_lon" "$full_zoom" &
    map_pid=$!

    while true; do
        api_response=$(curl -sf "$RAINVIEWER_API")
        current_pic=$(last_radar_time "$api_response")
        if ((current_pic != last_pic)); then
            generate_radar_pic "$c_lat" "$c_lon" "$api_zoom" "$virtual_zoom" "$api_response"
            wait "$poly_pid" "$map_pid" 2>/dev/null

            magick -size "${PICTURE_SIZE}x${PICTURE_SIZE}" \
                xc:none "$MAP_PIC" -composite \
                "$CROPPED_RADAR_PIC" -compose dissolve -define compose:args=80 -composite \
                -compose over "$POLYGON_BORDER_PIC" -composite \
                assets/NESW.png -composite \
                "$COMPOSITE_PIC" 2>/dev/null

            tput cup $(((LINES - PIC_H) / 2 + 2)) $(((COLUMNS - LOGO_L) / 2))
            chafa --polite on --probe off "$COMPOSITE_PIC"
            rm -f "$BUSY_LOCK" 2>/dev/null

            read -r min sec <<<"$(radar_sleep_time "$api_response")"
            sleep "$min" "$sec"
        else
            sleep 3
            continue
        fi
        last_pic=$current_pic
    done
}
