#!/usr/bin/env bash

select_options() {
    local \
        KB_PID="$1" PICTURE_SIZE_LIST=(256 512) \
        ZOOM_LIST=(1 2 3 4 5 6 7) VIRTUAL_ZOOM_LIST=(1 2 3 4 5 6 7 8 9 10) \
        SHAPE_LIST=('rectangle' 'circle' 'polygon') SCALE_FACTOR \
        CROP_SIZE CROP_X CROP_Y PICTURE_SIZE TILE_SIZE ZOOM \
        VIRTUAL_ZOOM SHAPE

    stty echo

    tput cup $(((LINES - 1) / 2)) $(((COLUMNS - 19) / 2))
    echo "Select picture size"
    select size in "${PICTURE_SIZE_LIST[@]}"; do
        if [[ -n "$size" ]]; then
            PICTURE_SIZE="$size"
            TILE_SIZE=$PICTURE_SIZE
            break
        else
            echo "Invalid choice, try again."
        fi
    done

    tput clear
    tput cup $(((LINES - 1) / 2)) $(((COLUMNS - 11) / 2))

    echo "Select Zoom"
    select zoom in "${ZOOM_LIST[@]}"; do
        if [[ -n "$zoom" ]]; then
            ZOOM="$zoom"
            break
        else
            echo "Invalid choice, try again."
        fi
    done

    tput clear
    tput cup $(((LINES - 1) / 2)) $(((COLUMNS - 50) / 2))

    echo "Use virtual zoom (simulates higher zooms)"
    select ans in 'yes' 'no'; do
        if [[ "$ans" == 'yes' ]]; then
            select v_zoom in "${VIRTUAL_ZOOM_LIST[@]}"; do
                if [[ -n "$v_zoom" ]]; then
                    VIRTUAL_ZOOM="$v_zoom"
                    break
                else
                    echo "Invalid choice, try again."
                fi
            done
            break
        elif [[ "$ans" == 'no' ]]; then
            VIRTUAL_ZOOM=0
            break
        else
            echo "Invalid choice, try again."
        fi
    done

    SCALE_FACTOR=$((2 ** VIRTUAL_ZOOM))
    CROP_SIZE=$((PICTURE_SIZE / SCALE_FACTOR))
    CROP_X=$(((PICTURE_SIZE - CROP_SIZE) / 2))
    CROP_Y=$(((PICTURE_SIZE - CROP_SIZE) / 2))

    tput clear
    tput cup $(((LINES - 1) / 2)) $(((COLUMNS - 28) / 2))

    echo "Choose the shape of the area"
    select shape in "${SHAPE_LIST[@]}"; do
        if [[ -n "$shape" ]]; then
            SHAPE="$shape"
            break
        else
            echo "Invalid choice, try again."
        fi
    done

    stty -echo
    kill -CONT "$KB_PID"

    generate_data \
        "$PICTURE_SIZE" "$TILE_SIZE" "$ZOOM" "$VIRTUAL_ZOOM" \
        "$SHAPE" "$SCALE_FACTOR" "$CROP_SIZE" "$CROP_X" "$CROP_Y" &
}

calculate_color() {
    local \
        CENTER_LAT="$1" CENTER_LON="$2" TILE_SIZE="$3" \
        PICTURE_SIZE="$4" ZOOM="$5" PIC="$6" POLYGON=""

    magick "$PIC" -depth 8 txt:- >pixels.txt
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
    local \
        CENTER_LAT="$1" CENTER_LON="$2" TILE_SIZE="$3" \
        PICTURE_SIZE="$4" ZOOM="$5" POLYGON="" \
        CENTER_X CENTER_Y WORLD_X WORLD_Y

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
    done <test.csv

    echo "$POLYGON"
}

draw_polygon() {
    local \
        CENTER_LAT="$1" CENTER_LON="$2" TILE_SIZE="$3" \
        PICTURE_SIZE="$4" ZOOM="$5" SHAPE="$6" \
        POLYGON_PIC="$7" POLYGON=""

    POLYGON="$(pixel_coords "$CENTER_LAT" "$CENTER_LON" "$TILE_SIZE" "$PICTURE_SIZE" "$ZOOM")"

    magick -size "${PICTURE_SIZE}x${PICTURE_SIZE}" xc:none -fill \
        none -stroke lime -strokewidth 1 \
        -draw "$SHAPE $POLYGON" "$POLYGON_PIC"
}

generate_data() {
    local \
        PICTURE_SIZE="$1" TILE_SIZE="$2" ZOOM="$3" VIRTUAL_ZOOM="$4" \
        SHAPE="$5" SCALE_FACTOR="$6" CROP_SIZE="$7" CROP_X="$8" \
        CROP_Y="$9" RAINVIEWER_API='https://api.rainviewer.com/public/weather-maps.json' \
        RAINVIEWER_PIC POLYGON_PIC COMPOSITE_PIC CROPPED_RADAR RESPONSE \
        TIME LAST_TIME=99 IMAGE_PATH LAT LON

    RAINVIEWER_PIC=$(mktemp --suffix=.png)
    POLYGON_PIC=$(mktemp --suffix=.png)
    COMPOSITE_PIC=$(mktemp --suffix=.png)
    CROPPED_RADAR=$(mktemp --suffix=.png)

    IFS=, read -r LAT LON <test.csv

    draw_polygon \
        "$LAT" "$LON" "$TILE_SIZE" "$PICTURE_SIZE" \
        "$((ZOOM + VIRTUAL_ZOOM))" "$SHAPE" "$POLYGON_PIC" &
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
                +repage -filter point \
                -resize "${PICTURE_SIZE}x${PICTURE_SIZE}" \
                "$CROPPED_RADAR"

            wait "$POLYGON_PID"

            magick \
                -size "${PICTURE_SIZE}x${PICTURE_SIZE}" xc:none \
                "$CROPPED_RADAR" -composite \
                "$POLYGON_PIC" -composite \
                "$COMPOSITE_PIC"

            tput clear
            # tput cup $(((LINES - 30) / 2)) $(((COLUMNS - 50) / 2))
            chafa --polite on --probe off "$COMPOSITE_PIC"
            LAST_TIME=$TIME

            # calculate_color \
            # "$LAT" "$LON" "$TILE_SIZE" \
            # "$PICTURE_SIZE" "$((ZOOM + VIRTUAL_ZOOM))" "$POLYGON_PIC"
        fi
        sleep 60
    done
}

fatal() {
    tput setaf 1
    echo "[error]" "$@" >&2
    tput sgr0
    exit 1
}

create_pipe() {
    local KB_PIPE=/tmp/kb_raintracker.$$
    mkfifo "$KB_PIPE" || fatal "failed to create pipes"
    exec 3<>"$KB_PIPE" || fatal "failed to open pipes"
    rm "$KB_PIPE"
}

cleanup() {
    pkill -P $$
    tput cnorm
    tput rmcup
    stty echo 2>/dev/null
}

setup() {
    tput civis
    tput smcup
    stty -echo
    exec 4</dev/tty || fatal 'no terminal detected'
    create_pipe
}

keyboard_input() {
    local escape_char=$'\x1b'
    while true; do
        local data=
        read -rsn1 data 2>/dev/null || return
        if [[ $data == "$escape_char" ]]; then
            read -rsn2 data 2>/dev/null || return
        fi

        local output=
        case "$data" in
        q) output='key-quit' ;;
        esac

        if [[ -n $output ]]; then
            echo "$output" >&3
        fi
    done
}

event_handler() {
    local KB_PID
    keyboard_input <&4 &
    KB_PID=$!
    echo "choose-settings" >&3
    while true; do
        if read -ra data -t 1 <&3; then
            local event=${data[0]}
            case "$event" in
            key-quit) exit ;;
            choose-settings)
                kill -TSTP $KB_PID
                select_options "$KB_PID"
                ;;
            esac
        fi
    done
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
