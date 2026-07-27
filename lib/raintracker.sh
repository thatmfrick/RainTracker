calculate_area_points() {
    local poly_pic="$1" radar_pic="$2"
    local poly_pixels_color_filtered radar_pixels_color_filtered
    local final_points count len

    poly_pixels_color_filtered=$(mktemp --suffix=.txt)
    radar_pixels_color_filtered=$(mktemp --suffix=.txt)
    final_points=$(mktemp --suffix=.txt)

    magick "$poly_pic" -depth 8 txt:- | tail -n +2 | awk '$3 != "#00000000"' | cut -d: -f1 >"$poly_pixels_color_filtered"
    magick "$radar_pic" -depth 8 txt:- | tail -n +2 | awk '$3 != "#00000000" {print $1, $3}' >"$radar_pixels_color_filtered"

    awk -F': ' 'FNR==NR{color[$1]=$2;next} ($0 in color){print color[$0]}' "$radar_pixels_color_filtered" "$poly_pixels_color_filtered" >"$final_points"

    count=$(wc -l <"$final_points")
    len=$(((COLUMNS - 29) / 2))

    tput cup $(((LINES + 29) / 2)) $(((COLUMNS - 29) / 2))
    printf "%${len}s" ''
    if ((count == 0)); then
        tput cup $(((LINES + 29) / 2)) $(((COLUMNS - 29) / 2))
        echo "No precipitations in the area"
    else
        tput cup $(((LINES + 29) / 2)) $(((COLUMNS - 34) / 2))
        echo "Possible precipitations in the area"
    fi
}

latlon_to_pixel() {
    local lat="$1" lon="$2" tile_size="$3" zoom="$4"
    awk -v lat="$lat" -v lon="$lon" \
        -v tile_size="$tile_size" -v zoom="$zoom" '
        BEGIN {
            if (lat > 85.051129)  lat = 85.051129
            if (lat < -85.051129) lat = -85.051129
            
            pi = atan2(0, -1)
            scale = 2 ^ zoom
            lat_rad = lat * (pi / 180)
            
            ang = (pi / 4) + (lat_rad / 2)
            tan_val = sin(ang) / cos(ang)

            x = tile_size * scale * (( lon + 180) / 360)
            y = tile_size * scale * (0.5 - log(tan_val) / (2 * pi))
            
            printf "%.0f %.0f\n", x, y
        }
    '
}

pixel_coords() {
    local center_lat="$1" center_lon="$2"
    local tile_size="$3" PICTURE_SIZE="$4"
    local zoom="$5" csv_file="$6" polygon=""
    local center_x center_y world_x world_y

    read -r center_x center_y <<<"$(latlon_to_pixel "$center_lat" "$center_lon" "$tile_size" "$zoom")"

    while IFS=, read -r lat lon; do
        read -r world_x world_y <<<"$(latlon_to_pixel "$lat" "$lon" "$tile_size" "$zoom")"

        px=$(awk -v x="$world_x" -v cx="$center_x" -v img_size="$PICTURE_SIZE" '
                BEGIN {
                    printf "%.0f", img_size/2 + (x - cx)
                }
            ')

        py=$(awk -v y="$world_y" -v cy="$center_y" -v img_size="$PICTURE_SIZE" '
                BEGIN { 
                    printf "%.0f", img_size/2 + (y - cy)
                }
            ')

        polygon+="$px,$py "
    done <"$csv_file"

    echo "$polygon"
}

draw_polygon() {
    local center_lat="$1" center_lon="$2"
    local tile_size="$3" zoom="$4" shape="$5"
    local polygon_area_pic="$6" polygon_border_pic="$7"
    local csv_file="$8" polygon=""

    polygon="$(pixel_coords "$center_lat" "$center_lon" "$tile_size" "$PICTURE_SIZE" "$zoom" "$csv_file")"

    magick -size "${PICTURE_SIZE}x${PICTURE_SIZE}" xc:none -fill none \
        -stroke lime -strokewidth 2 \
        -draw "$shape $polygon" "$polygon_border_pic"

    magick -size "${PICTURE_SIZE}x${PICTURE_SIZE}" xc:none -fill lime \
        -stroke lime -strokewidth 2 \
        -draw "$shape $polygon" "$polygon_area_pic"
}

get_shape() {
    stty echo

    local kb_pid="$1"
    local csv_dir=config
    local selected_file file_points shape location

    mkdir "$csv_dir" 2>/dev/null

    if [ -z "$(ls -A "$csv_dir" 2>/dev/null)" ]; then
        fatal 'No files to source'
    fi

    tput cup $(((LINES + 1) / 2)) $(((COLUMNS - $(echo 'Select one of the following files:' | wc -L)) / 2))
    printf '%s\n' "Select one of the following files: "

    select file in "$csv_dir/"*; do
        selected_file="$file"
        file_points=$(wc -l <"$selected_file")
        break
    done

    clean_half_screen

    tput cup $(((LINES + 1) / 2)) $(((COLUMNS - $(echo 'Insert location name:' | wc -L)) / 2))
    printf '%s\n' "Insert location name: "
    tput cup $(((LINES + 1) / 2)) $(((1 + COLUMNS + $(echo 'Insert location name:' | wc -L)) / 2))
    read -r location

    stty -echo
    kill -CONT "$kb_pid"

    while ((i < LINES / 2)); do
        tput cup $((LINES / 2 + i)) 0
        printf "%${COLUMNS}s" ' '
        ((i++))
    done

    if ((file_points > 2)); then
        shape='polygon'
    elif ((file_points == 2)); then
        shape='circle'
    else
        fatal "You need at least 2 poins"
    fi

    echo "selected-shape|$shape|$selected_file|$location" >&3
}

zoom_select() {
    local kb_pid="$1"
    local full_zoom
    local zoom_values=({1..16})

    stty echo

    select value in "${zoom_values[@]}"; do
        full_zoom=$value
        break
    done

    stty -echo
    kill -CONT "$kb_pid"

    awk -v full_zoom="$full_zoom" -v picture_size="$PICTURE_SIZE" '
        BEGIN {
            if (full_zoom > 7) {
                api_zoom = 7 
                virtual_zoom = full_zoom - 7
            }

            if (full_zoom <= 7) {
                api_zoom = full_zoom 
                virtual_zoom = 0
            }

            scale_factor = 2 ^ virtual_zoom
            crop_size = picture_size / scale_factor
            crop_x = (picture_size - crop_size) / 2
            crop_y = (picture_size - crop_size) / 2

            printf "%.0f %.0f %.0f %.0f %.0f\n", api_zoom, virtual_zoom, crop_size, crop_x, crop_y
        }
    '
}

generate_data() {
    local tile_size zoom="$1" virtual_zoom="$2" shape="$3"
    local crop_size="$4" crop_x="$5" crop_y="$6" csv_file="$7" location="$8"
    tile_size=$PICTURE_SIZE

    local response time last_time=99 image_path lat lon

    local rainviewer_pic polygon_border_pic polygon_area_pic
    local composite_pic cropped_radar_pic

    rainviewer_pic=$(mktemp --suffix=.png)
    polygon_border_pic=$(mktemp --suffix=.png)
    polygon_area_pic=$(mktemp --suffix=.png)
    composite_pic=$(mktemp --suffix=.png)
    cropped_radar_pic=$(mktemp --suffix=.png)

    IFS=, read -r lat lon <"$csv_file"

    draw_polygon \
        "$lat" "$lon" "$tile_size" \
        "$((zoom + virtual_zoom))" "$shape" \
        "$polygon_area_pic" "$polygon_border_pic" "$csv_file" &
    polygon_pid=$!

    while true; do
        response=$(curl -sf "$RAINVIEWER_API")
        time=$(date --date "@$(jq -r '.radar.past[-1].time' <<<"$response")" +%M)
        image_path="$(jq -r '.host + .radar.past[-1].path' <<<"$response")"
        if ((10#$time != 10#$last_time)); then
            curl -sf "$image_path/$PICTURE_SIZE/$zoom/$lat/$lon/0/1_1.png" >"$rainviewer_pic"

            magick \
                "$rainviewer_pic" \
                -crop "${crop_size}x${crop_size}+${crop_x}+${crop_y}" \
                +repage \
                -filter point \
                -resize "${PICTURE_SIZE}x${PICTURE_SIZE}" \
                "$cropped_radar_pic"

            wait "$polygon_pid"

            magick \
                -size "${PICTURE_SIZE}x${PICTURE_SIZE}" xc:black \
                "$cropped_radar_pic" -composite \
                "$polygon_border_pic" -composite \
                -fill none -stroke white -strokewidth 2 \
                -draw "rectangle 0,0,$((PICTURE_SIZE - 1)),$((PICTURE_SIZE - 1))" \
                "$composite_pic"

            tput cup $(((LINES - 22) / 2)) $(((COLUMNS - 40) / 2))
            printf '%s' "${SOFT_BLUE}${RESET} $location"

            tput cup $(((LINES - 17) / 2)) $(((COLUMNS - 40) / 2))
            chafa --polite on --probe off "$composite_pic"

            calculate_area_points "$polygon_area_pic" "$cropped_radar_pic"

            last_time=$time
        fi
        sleep 60
    done
}

draw_logo() {
    local logo_width=82
    local logo_height=6
    local x=$((COLUMNS / 2 - logo_width / 2))
    local y=$((logo_height + 6))

    while IFS= read -r line; do
        tput cup $((y - 10)) "$x"
        echo -n "$line"
        ((y++))
    done <<<"$LOGO"
}

draw_menu() {
    local i=0
    while IFS= read -r line; do
        tput cup $((LINES - 4 + i)) $(((COLUMNS - 14) / 2))
        printf %s "$line"
        ((i++))
    done <<<"$MENU_LIST"
}
