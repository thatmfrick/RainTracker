calculate_area_points() {
    local poly_pic="$1" radar_pic="$2"
    local poly_pixels_color_filtered radar_pixels_color_filtered
    local final_points count

    poly_pixels_color_filtered=$(mktemp --suffix=.txt)
    radar_pixels_color_filtered=$(mktemp --suffix=.txt)
    final_points=$(mktemp --suffix=.txt)

    magick "$poly_pic" -depth 8 txt:- | tail -n +2 | awk '$3 != "#00000000"' | cut -d: -f1 >"$poly_pixels_color_filtered"
    magick "$radar_pic" -depth 8 txt:- | tail -n +2 | awk '$3 != "#00000000" {print $1, $3}' >"$radar_pixels_color_filtered"

    awk -F': ' 'FNR==NR{color[$1]=$2;next} ($0 in color){print color[$0]}' "$radar_pixels_color_filtered" "$poly_pixels_color_filtered" >"$final_points"

    count=$(wc -l <"$final_points")

    tput cup $((LINES / 2)) $((COLUMNS / 2))
    printf '%40s' ''
    if ((count == 0)); then
        tput cup $((LINES / 2)) $((COLUMNS / 2))
        echo "No precipitations in the area"
    else
        tput cup $((LINES / 2)) $((COLUMNS / 2))
        echo "Possible precipitations in the area"
    fi
}

draw_polygon() {
    local lat="$1" lon="$2"
    local tile_size="$3" zoom="$4" shape="$5"
    local polygon_area_pic="$6" polygon_border_pic="$7"
    local csv_file="$8" polygon=""
    local poly_centroid_x poly_centroid_y
    local offset_x offset_y

    polygon="$(pixel_coords "$lat" "$lon" "$tile_size" "$PICTURE_SIZE" "$zoom" "$csv_file")"
    read -r poly_centroid_x poly_centroid_y <<<"$(centroid_poly "$polygon")"

    offset_x=$((256 - poly_centroid_x))
    offset_y=$((256 - poly_centroid_y))

    magick -size "${PICTURE_SIZE}x${PICTURE_SIZE}" xc:none -fill none \
        -stroke lime -strokewidth 2 \
        -draw "translate $offset_x,$offset_y $shape $polygon" "$polygon_border_pic"

    magick -size "${PICTURE_SIZE}x${PICTURE_SIZE}" xc:none -fill lime \
        -stroke none -strokewidth 2 \
        -draw "translate $offset_x,$offset_y $shape $polygon" "$polygon_area_pic"
}

get_shape() {
    local kb_pid="$1"
    local csv_dir=config
    local selected_file file_points shape location
    local files=("$csv_dir"/*) max_index
    local i=0 j=0 k=0 files=("$csv_dir/"*) max=""
    # local half_files
    # local half_files=$((${#files[@]} / 2))

    max_index=$((${#files[@]} - 1))

    mkdir "$csv_dir" 2>/dev/null

    while ((k < 22)); do
        tput cup $((LINES - 13 - k)) $((COLUMNS / 2))
        printf "%${COLUMNS}s" ''
        ((k++))
    done

    if [ -z "$(ls -A "$csv_dir" 2>/dev/null)" ]; then
        fatal 'No files to source'
    fi

    kill -TSTP "$kb_pid"
    stty echo icanon #all my homies hate icanon
    tput cnorm

    tput cup $(((LINES - 17) / 2)) $((COLUMNS / 2))
    printf '%s' "📃 File: "

    for i in "${!files[@]}"; do
        len=${#files[$i]}
        if ((i <= 15)); then
            ((len > max)) && max=$len
        fi

        if ((i > 15)); then
            tput cup $((LINES / 2 - 7 + j)) $(((COLUMNS + 2) / 2 + 4 + max))
            printf '%s%s\n' "${SOFT_BLUE}$i${RESET}. " "${files[$i]}"
            ((j++))
        else
            tput cup $((LINES / 2 - 7 + i)) $(((COLUMNS + 2) / 2))
            printf "%s%s\n" "${SOFT_BLUE}$i${RESET}. " "${files[$i]}"
        fi
    done

    while true; do
        tput cup $(((LINES - 17) / 2)) $((9 + COLUMNS / 2))
        printf "%${ans_len}s" ''
        read -r ans
        if [[ "$ans" =~ ^[0-9]+$ ]] && ((ans >= 0 && ans <= max_index)); then
            selected_file="${files[$ans]}"
            file_points=$(wc -l <"$selected_file")
            break
        fi
        ans_len=$(echo "$ans" | wc -L)
    done

    i=0
    while ((i < 22)); do
        tput cup $((LINES - 13 - i)) $((COLUMNS / 2))
        printf "%${COLUMNS}s" ' '
        ((i++))
    done

    tput cup $(((LINES - 17) / 2)) $((13 + COLUMNS / 2))
    printf '%20s' ''
    tput cup $(((LINES - 17) / 2)) $((COLUMNS / 2))
    printf '%s' "🗺️ Location: "
    tput cup $(((LINES - 17) / 2)) $((13 + COLUMNS / 2))
    read -r location

    tput civis
    stty -echo -icanon
    kill -CONT "$kb_pid"

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
    local value full_zoom

    tput cup $(((LINES - 14) / 2)) $((COLUMNS / 2))
    printf '%s' "🔎 Zoom: "

    tput cup $(((LINES - 14) / 2)) $((9 + COLUMNS / 2))
    printf '%12s' ''

    kill -TSTP "$kb_pid"
    stty echo icanon
    tput cnorm

    while true; do
        tput cup $(((LINES - 14) / 2)) $((9 + COLUMNS / 2))
        read -r value
        if [[ "$value" =~ ^[0-9]+$ ]] && ((value >= 1 && value <= 20)); then
            full_zoom=$value
            break
        fi
        var_len=$(echo "$value" | wc -L)
        tput cup $(((LINES - 14) / 2)) $((9 + COLUMNS / 2))
        printf "%${var_len}s" ''
    done

    tput civis
    stty -echo -icanon
    kill -CONT "$kb_pid"

    echo "selected-zoom|$full_zoom" >&3
}

generate_data() {
    local zoom="$1" virtual_zoom="$2" shape="$3"
    local crop_size="$4" crop_x="$5" crop_y="$6"
    local csv_file="$7" location="$8"

    local tile_size centroid_lat centroid_lon
    local new_pic_time request_time minutes_diff seconds_diff
    local first_call='true' short_sleep old_pic_time response image_path
    local rainviewer_pic polygon_border_pic polygon_area_pic composite_pic cropped_radar_pic
    local polygon_pid

    tile_size=$PICTURE_SIZE

    rainviewer_pic=$(mktemp --suffix=.png)
    polygon_border_pic=$(mktemp --suffix=.png)
    polygon_area_pic=$(mktemp --suffix=.png)
    composite_pic=$(mktemp --suffix=.png)
    cropped_radar_pic=$(mktemp --suffix=.png)

    if [[ $shape -eq "polygon" ]]; then
        read -r centroid_lat centroid_lon <<<"$(centroid_radar "$csv_file")"
    else
        IFS=, read -r centroid_lat centroid_lon <"$csv_file"
    fi

    draw_polygon \
        "$centroid_lat" "$centroid_lon" "$tile_size" \
        "$((zoom + virtual_zoom))" "$shape" \
        "$polygon_area_pic" "$polygon_border_pic" "$csv_file" &
    polygon_pid=$!

    while true; do
        response=$(curl -sf "$RAINVIEWER_API")
        new_pic_time=$(jq -r '.radar.past[-1].time' <<<"$response") # last picture timestamp
        request_time=$(date +%s)                                    # time when the request was made
        # generated_time=$(jq -r '.generated' <<<"$response")         # time when the request was made
        minutes_diff=$(((request_time - new_pic_time) / 60)) # time passed between the request and last radar update
        seconds_diff=$(((request_time - new_pic_time) % 60)) # same as above but in seconds

        if $first_call; then
            core_fun "$response" "$zoom" "$centroid_lat" "$centroid_lon" "$crop_size" "$crop_x" "$crop_y" "$rainviewer_pic" "$cropped_radar_pic" "$composite_pic" "$polygon_border_pic" "$polygon_area_pic" "$location" "$polygon_pid"
            first_call='false'
            short_sleep=$((10 - minutes_diff))
            old_pic_time=$new_pic_time
            sleep "${short_sleep}m" "${seconds_diff}s"
            continue
        fi

        if ((new_pic_time != old_pic_time)); then # even if 10 minutes have passed it does not guarantee the json is updated
            core_fun "$response" "$zoom" "$centroid_lat" "$centroid_lon" "$crop_size" "$crop_x" "$crop_y" "$rainviewer_pic" "$cropped_radar_pic" "$composite_pic" "$polygon_border_pic" "$polygon_area_pic" "$location" "$polygon_pid"
            old_pic_time=$new_pic_time
            sleep 600
        else # in case json is not updated wait 10 sec and try again
            sleep 10
        fi
    done
}

core_fun() {
    local response="$1" zoom="$2" lat="$3" lon="$4"
    local crop_size="$5" crop_x="$6" crop_y="$7"
    local rainviewer_pic="$8" cropped_radar_pic="$9" composite_pic="${10}"
    local polygon_border_pic="${11}" polygon_area_pic="${12}" location="${13}"
    local polygon_pid="${14}"

    draw_logo
    draw_menu
    image_path="$(jq -r '.host + .radar.past[-1].path' <<<"$response")"
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

    tput cup $(((LINES - 17) / 2)) $((COLUMNS / 2 - 82 / 2))
    chafa --polite on --probe off "$composite_pic"

    calculate_area_points "$polygon_area_pic" "$cropped_radar_pic"
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
        tput cup $((LINES - 12 + i)) $((COLUMNS / 2))
        printf %s "$line"
        ((i++))
    done <<<"$MENU_LIST"
}
