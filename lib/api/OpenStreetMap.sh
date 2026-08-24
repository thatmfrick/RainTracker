generate_map() {
    local c_lat="$1" c_lon="$2" full_zoom="$3"

    local tmpdir map_pic
    local tile_x tile_y offset_L offset_T
    local i=0 tx ty

    local map_pic="$CACHE_DIR/${c_lat}_${c_lon}_${full_zoom}.png"

    tmpdir=$(mktemp -d)
    read -r tile_x tile_y offset_L offset_T <<<"$(latlon_to_tile "$c_lat" "$c_lon" "$full_zoom")"

    if [[ ! -f "$map_pic" ]]; then
        for y in -1 0 1; do
            for x in -1 0 1; do
                tx=$((tile_x + x))
                ty=$((tile_y + y))
                curl -H "User-Agent: RainTracker.sh" -sf "https://tile.openstreetmap.org/$full_zoom/$tx/$ty.png" -o "$tmpdir/tile_${i}.png" &
                ((i++))
            done
        done
        wait
        magick "$tmpdir/tile_0.png" "$tmpdir/tile_1.png" "$tmpdir/tile_2.png" +append \
            \( "$tmpdir/tile_3.png" "$tmpdir/tile_4.png" "$tmpdir/tile_5.png" +append \) \
            \( "$tmpdir/tile_6.png" "$tmpdir/tile_7.png" "$tmpdir/tile_8.png" +append \) \
            -append \
            -crop "${PICTURE_SIZE}x${PICTURE_SIZE}+${offset_L}+${offset_T}" +repage "$MAP_PIC" 2>/dev/null
        cp "$MAP_PIC" "$map_pic"
        rm -rf "$tmpdir"
    else
        magick "$map_pic" "$MAP_PIC"
    fi
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
