latlon_to_pixel_calculi() {
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

zoom_calculi() {
    local full_zoom="$1"

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

pixel_coords() {
    local center_lat="$1" center_lon="$2"
    local tile_size="$3" PICTURE_SIZE="$4"
    local zoom="$5" csv_file="$6" polygon=""
    local center_x center_y world_x world_y

    read -r center_x center_y <<<"$(latlon_to_pixel_calculi "$center_lat" "$center_lon" "$tile_size" "$zoom")"

    while IFS=, read -r lat lon; do
        read -r world_x world_y <<<"$(latlon_to_pixel_calculi "$lat" "$lon" "$tile_size" "$zoom")"

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

        polygon+="$px,$py"$'\n'
    done <"$csv_file"

    echo "$polygon"
}

centroid_radar() {
    local csv_file="$1"
    awk -F, '{
        sum_lat += $1
        sum_lon += $2
        count++
    } END {
        print sum_lat / count, sum_lon / count
    }' "$csv_file"
}

centroid_poly() {
    local poly="$1"

    awk -F, '{
        sum_lat += $1
        sum_lon += $2
        count++
    } END {
        printf "%.0f %.0f", sum_lat / count, sum_lon / count
    }' <<<"$poly"
}
