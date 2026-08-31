draw_polygon() {
    local c_lat="$1" c_lon="$2"
    local full_zoom="$3" csv_file="$4"

    local c_px c_py
    local polygon=""

    read -r c_px c_py <<<"$(awk -f lib/math.awk -v lat="$c_lat" -v lon="$c_lon" -v zoom="$full_zoom" -e 'BEGIN { print latlon_to_pixel(lat, lon, zoom) }')"

    while IFS=, read -r lat lon || [[ -n "$lat" ]]; do
        read -r world_x world_y <<<"$(awk -f lib/math.awk -v lat="$lat" -v lon="$lon" -v zoom="$full_zoom" -e 'BEGIN { print latlon_to_pixel(lat, lon, zoom) }')"

        px=$((PICTURE_SIZE / 2 + world_x - c_px))
        py=$((PICTURE_SIZE / 2 + world_y - c_py))

        polygon+="$px,$py "
    done <"$csv_file"

    magick -size "${PICTURE_SIZE}x${PICTURE_SIZE}" xc:none -fill none \
        -stroke black -strokewidth 2 \
        -draw "polygon $polygon" "$POLYGON_BORDER_PIC"
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

    read -r c_lat c_lon <<<"$(awk -f lib/math.awk -v file="$csv_file" -e 'BEGIN { print centroid(file) }')"

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

            print_radar

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
