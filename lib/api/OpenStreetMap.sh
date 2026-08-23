tile() {
    local lat="$1" zoom="$2" idx="$3"
    echo "$CACHE_DIR/${lat}_${zoom}_${idx}.png"
}

generate_map() {
    local c_lat="$1" c_lon="$2" full_zoom="$3"

    local tile_x tile_y offset_L offset_T
    local i=0 tx ty

    read -r tile_x tile_y offset_L offset_T <<<"$(latlon_to_tile "$c_lat" "$c_lon" "$full_zoom")"

    for y in -1 0 1; do
        for x in -1 0 1; do
            tx=$((tile_x + x))
            ty=$((tile_y + y))
            if [[ ! -f "$CACHE_DIR/${c_lat}_${full_zoom}_${i}.png" ]]; then
                curl -H "User-Agent: RainTracker.sh" -sf "https://tile.openstreetmap.org/$full_zoom/$tx/$ty.png" -o "$CACHE_DIR/${c_lat}_${full_zoom}_${i}.png" &
            else
                continue
            fi
            ((i++))
        done
    done
    wait

    magick "$(tile "$c_lat" "$full_zoom" 0)" "$(tile "$c_lat" "$full_zoom" 1)" "$(tile "$c_lat" "$full_zoom" 2)" +append \
        \( "$(tile "$c_lat" "$full_zoom" 3)" "$(tile "$c_lat" "$full_zoom" 4)" "$(tile "$c_lat" "$full_zoom" 5)" +append \) \
        \( "$(tile "$c_lat" "$full_zoom" 6)" "$(tile "$c_lat" "$full_zoom" 7)" "$(tile "$c_lat" "$full_zoom" 8)" +append \) \
        -append \
        -crop "${PICTURE_SIZE}x${PICTURE_SIZE}+${offset_L}+${offset_T}" +repage "$MAP_PIC" 2>/dev/null
}

detect_location() {
    local csv_file="$1"

    local c_lat c_lon
    local location

    read -r c_lat c_lon <<<"$(calculate_centroid "$csv_file")"

    location=$(curl -H "User-Agent: RainTracker.sh" -s "https://nominatim.openstreetmap.org/reverse?format=json&lat=$c_lat&lon=$c_lon" | jq -r '.address | "\(.road // .hamlet // "N/A") - \(.village // .county // "N/A")"')

    location_len=$(echo "$location" | wc -L)
    echo "$location|$location_len"
}
