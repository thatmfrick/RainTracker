calculate_area_points() {
    local POLY_PIC="$1" RADAR_PIC="$2"
    local POLY_PIXELS_COLOR_FILTERED RADAR_PIXELS_COLOR_FILTERED
    local FINAL_POINTS COUNT

    POLY_PIXELS_COLOR_FILTERED=$(mktemp --suffix=.txt)
    RADAR_PIXELS_COLOR_FILTERED=$(mktemp --suffix=.txt)
    FINAL_POINTS=$(mktemp --suffix=.txt)

    magick "$POLY_PIC" -depth 8 txt:- | tail -n +2 | awk '$3 != "#00000000"' | cut -d: -f1 >"$POLY_PIXELS_COLOR_FILTERED"
    magick "$RADAR_PIC" -depth 8 txt:- | tail -n +2 | awk '$3 != "#00000000" {print $1, $3}' >"$RADAR_PIXELS_COLOR_FILTERED"

    awk -F': ' 'FNR==NR{color[$1]=$2;next} ($0 in color){print color[$0]}' "$RADAR_PIXELS_COLOR_FILTERED" "$POLY_PIXELS_COLOR_FILTERED" >"$FINAL_POINTS"

    COUNT=$(wc -l <"$FINAL_POINTS")

    if ((COUNT == 0)); then
        tput cup $((LINES + 1)) 0
        echo "No precipitations in the Area"
    else
        tput cup $((LINES + 1)) 0
        notify-send "Possible precepitation!!"
        echo "Possible precipitation in the Area"
    fi
}

latlon_to_pixel() {
    local LAT="$1" LON="$2" TILE_SIZE="$3" ZOOM="$4"
    awk -v lat="$LAT" -v lon="$LON" \
        -v tile_size="$TILE_SIZE" -v zoom="$ZOOM" '
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
    local CENTER_LAT="$1" CENTER_LON="$2"
    local TILE_SIZE="$3" PICTURE_SIZE="$4"
    local ZOOM="$5" csv_file="$6" POLYGON=""
    local CENTER_X CENTER_Y WORLD_X WORLD_Y

    read -r CENTER_X CENTER_Y <<<"$(latlon_to_pixel "$CENTER_LAT" "$CENTER_LON" "$TILE_SIZE" "$ZOOM")"

    while IFS=, read -r LAT LON; do
        read -r WORLD_X WORLD_Y <<<"$(latlon_to_pixel "$LAT" "$LON" "$TILE_SIZE" "$ZOOM")"

        PX=$(awk -v x="$WORLD_X" -v cx="$CENTER_X" -v img_size="$PICTURE_SIZE" '
                BEGIN {
                    printf "%.0f", img_size/2 + (x - cx)
                }
            ')

        PY=$(awk -v y="$WORLD_Y" -v cy="$CENTER_Y" -v img_size="$PICTURE_SIZE" '
                BEGIN { 
                    printf "%.0f", img_size/2 + (y - cy)
                }
            ')

        POLYGON+="$PX,$PY "
    done <"$csv_file"

    echo "$POLYGON"
}

draw_polygon() {
    local CENTER_LAT="$1" CENTER_LON="$2"
    local TILE_SIZE="$3" PICTURE_SIZE="$4"
    local ZOOM="$5" SHAPE="$6"
    local POLYGON_AREA_PIC="$7" POLYGON_BORDER_PIC="$8" csv_file="$9" POLYGON=""

    POLYGON="$(pixel_coords "$CENTER_LAT" "$CENTER_LON" "$TILE_SIZE" "$PICTURE_SIZE" "$ZOOM" "$csv_file")"

    magick -size "${PICTURE_SIZE}x${PICTURE_SIZE}" xc:none -fill none \
        -stroke lime -strokewidth 2 \
        -draw "$SHAPE $POLYGON" "$POLYGON_BORDER_PIC"

    magick -size "${PICTURE_SIZE}x${PICTURE_SIZE}" xc:none -fill lime \
        -stroke lime -strokewidth 2 \
        -draw "$SHAPE $POLYGON" "$POLYGON_AREA_PIC"
}

get_shape() {
    stty echo

    local csv_dir=config
    local selected_file file_points shape

    mkdir "$csv_dir" 2>/dev/null

    if [ -z "$(ls -A "$csv_dir" 2>/dev/null)" ]; then
        fatal 'No files to source'
    fi

    tput cup $(((LINES + 1) / 2)) $(((COLUMNS - $(echo 'Select one of the .csv files:' | wc -L)) / 2))
    printf '%s\n' "Select one of the following files: "

    select file in "$csv_dir/"*; do
        selected_file="$file"
        file_points=$(wc -l <"$selected_file")
        break
    done

    tput clear

    if ((file_points > 2)); then
        shape='polygon'
    elif ((file_points == 2)); then
        tput cup $(((LINES + 1) / 2)) $(((COLUMNS - $(echo 'Select the shape (1=Square; 2=Circle):' | wc -L)) / 2))
        printf '%s\n' "Select the shape (1=Square; 2=Circle): "
        select num in 1 2; do
            case $num in
            1) shape='square' ;;
            2) shape='circle' ;;
            esac
            break
        done
    fi

    tput clear

    echo "selected-shape $shape $selected_file" >&3
}

select_options() {
    local kb_pid="$1" shape="$2" csv_file="$3"
    local picture_size=512
    local api_zoom virtual_zoom
    local crop_size crop_x crop_y
    local shape

    printf '%s\n' "Select the zoom level"
    read -r api_zoom virtual_zoom crop_size crop_x crop_y <<<"$(zoom_select "$picture_size")"

    tput clear

    stty -echo
    kill -CONT "$kb_pid"

    generate_data \
        "$picture_size" "$picture_size" "$api_zoom" "$virtual_zoom" \
        "$shape" "$crop_size" "$crop_x" "$crop_y" "$csv_file" &
}

zoom_select() {
    local picture_size="$1"
    local full_zoom
    local zoom_values=({1..16})

    select value in "${zoom_values[@]}"; do
        full_zoom=$value
        break
    done

    awk -v full_zoom="$full_zoom" -v picture_size="$picture_size" '
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
    local PICTURE_SIZE="$1" TILE_SIZE="$2" ZOOM="$3" VIRTUAL_ZOOM="$4"
    local SHAPE="$5" CROP_SIZE="$6" CROP_X="$7" CROP_Y="$8" csv_file="$9"

    local RAINVIEWER_API='https://api.rainviewer.com/public/weather-maps.json'
    local RESPONSE TIME LAST_TIME=99 IMAGE_PATH LAT LON

    local RAINVIEWER_PIC POLYGON_BORDER_PIC POLYGON_AREA_PIC
    local COMPOSITE_PIC CROPPED_RADAR_PIC

    RAINVIEWER_PIC=$(mktemp --suffix=.png)
    POLYGON_BORDER_PIC=$(mktemp --suffix=.png)
    POLYGON_AREA_PIC=$(mktemp --suffix=.png)
    COMPOSITE_PIC=$(mktemp --suffix=.png)
    CROPPED_RADAR_PIC=$(mktemp --suffix=.png)

    IFS=, read -r LAT LON <"$csv_file"

    draw_polygon \
        "$LAT" "$LON" "$TILE_SIZE" "$PICTURE_SIZE" \
        "$((ZOOM + VIRTUAL_ZOOM))" "$SHAPE" \
        "$POLYGON_AREA_PIC" "$POLYGON_BORDER_PIC" "$csv_file" &
    POLYGON_PID=$!

    while true; do
        RESPONSE=$(curl -sf "$RAINVIEWER_API")
        TIME=$(date --date "@$(jq -r '.radar.past[-1].time' <<<"$RESPONSE")" +%M)
        IMAGE_PATH="$(jq -r '.host + .radar.past[-1].path' <<<"$RESPONSE")"
        if ((10#$TIME != 10#$LAST_TIME)); then
            curl -sf "$IMAGE_PATH/$PICTURE_SIZE/$ZOOM/$LAT/$LON/0/1_1.png" >"$RAINVIEWER_PIC"

            magick \
                "$RAINVIEWER_PIC" \
                -crop "${CROP_SIZE}x${CROP_SIZE}+${CROP_X}+${CROP_Y}" \
                +repage \
                -resize "${PICTURE_SIZE}x${PICTURE_SIZE}" \
                "$CROPPED_RADAR_PIC"

            wait "$POLYGON_PID"

            magick \
                -size "${PICTURE_SIZE}x${PICTURE_SIZE}" xc:none \
                "$CROPPED_RADAR_PIC" -composite \
                "$POLYGON_BORDER_PIC" -composite \
                "$COMPOSITE_PIC"

            chafa --clear --polite on --probe off "$COMPOSITE_PIC"

            calculate_area_points "$POLYGON_AREA_PIC" "$CROPPED_RADAR_PIC"

            LAST_TIME=$TIME
        fi
        sleep 60
    done
}

draw_logo() {
    local logo_width=82
    local logo_height=6
    local x=$((COLUMNS / 2 - logo_width / 2))
    local y=$((LINES / 2 - logo_height / 2))

    while IFS= read -r line; do
        tput cup $((y - 10)) "$x"
        echo -n "$line"
        ((y++))
    done <<<"$LOGO"
}

# Every tile is 256px, at zoom level 7 we will have 2^7 tiles = 128x128 grids so 256*2^7=32768px that will cover the whole world.
# 2^7 is like the scale.

# Now in order to convert a given longitude into a x pixel position: PIXEL_X = MAX_PX * (0.5 + lon / 360).
# This (0.5 + lon / 360) will print a value (to 0 to 1) that is representing proportionally where that longitude sits in like a percentage, that longitude is for example 73% of the way across the map, left to right.

# Multiplying this by MAX_PX we will get the actual pixel number.

# Longitude covers the whole world horizontally from -180 to +180 degrees
# lon = -180° -> 0.5 + (-180/360) = 0 (far left edge)
# lon = 180° -> 0.5 + (180/360) = 1 (far right edge)
# lon = 0° -> 0.5 + (0/365) = 0.5 (center of the map)

# in order to calculate the latitude in pixels we have to use this formula that icludes the Mercator stretching function that we divide by 4pi and subtract by 0.5 that squashes the value back to a usable 0-1 fraction (0 = top of the map, 1 = bottom)

# y = tile_size * (0.5 - log((1 + siny) / (1 - siny)) / (4 * pi))

# siny=sin(lat *pi / 180)
