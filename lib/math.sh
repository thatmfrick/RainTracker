zoom_calculi() {
    local virtual_zoom="$1"

    awk -v virtual_zoom="$virtual_zoom" -v picture_size="$PICTURE_SIZE" '
        BEGIN {
            scale_factor = 2 ^ virtual_zoom
            crop_size = picture_size / scale_factor
            crop_x = (picture_size - crop_size) / 2
            crop_y = (picture_size - crop_size) / 2

            print crop_size, crop_x, crop_y
        }
    '
}

# Web Mercator
latlon_to_tile() {
    local lat="$1" lon="$2"
    local zoom="$3"

    awk -v lat="$lat" -v lon="$lon" -v zoom="$zoom" '
        function sec(x) { return 1/cos(x) }
        function tan(x) { return sin(x) / cos(x) }
        BEGIN {
            PI = atan2(0, -1)
            lat_rad = lat * (PI / 180)
            n = 2^zoom  

            x_float = n * (lon + 180) / 360
            x_tile = int(x_float)
            
            y_float = n * (1 - (log(tan(lat_rad) + sec(lat_rad)) / PI)) / 2
            y_tile = int(y_float)

            left_offset = int((x_float-x_tile) * 256)
            top_offset = int((y_float - y_tile) * 256)

            print x_tile, y_tile, left_offset, top_offset
        }
    '
}

# source: https://medium.com/@suverov.dmitriy/how-to-convert-latitude-and-longitude-coordinates-into-pixel-offsets-8461093cb9f5

latlon_to_pixel() {
    local lat="$1" lon="$2" zoom="$3"
    awk -v lat="$lat" -v lon="$lon" \
        -v tile_size="$TILE_SIZE" -v zoom="$zoom" '
        function tan(x) { return sin(x) / cos(x) }
        BEGIN {
            mapWidth = tile_size * 2^zoom
            mapHeight = mapWidth
            FE = 180
            PI = atan2(0, -1)
            radius = mapWidth / (2 * PI)

            lonRad = ((lon + FE) * PI) /180
            x = int(lonRad * radius)

            latRad = (lat * PI) / 180
            verticalOffsetFromEquator = radius * log(tan(PI/4 + latRad /2))

            y = int(mapHeight / 2 - verticalOffsetFromEquator)

            print x, y
        }
    '
}

pixel_coords() {
    local c_px="$1" c_py="$2"
    local zoom="$3" csv_file="$4" polygon=""
    local world_x world_y

    #having to run another time inorder to read last line
    while IFS=, read -r lat lon || [[ -n "$lat" ]]; do
        read -r world_x world_y <<<"$(latlon_to_pixel "$lat" "$lon" "$zoom")"

        px=$(awk -v x="$world_x" -v c_px="$c_px" -v img_size="$PICTURE_SIZE" '
                BEGIN {
                    px = int(img_size/2 + (x - c_px))
                    print px
                }
            ')

        py=$(awk -v y="$world_y" -v c_py="$c_py" -v img_size="$PICTURE_SIZE" '
                BEGIN { 
                    py = int(img_size/2 + (y - c_py))
                    print py
                }
            ')

        polygon+="$px,$py "
    done <"$csv_file"

    echo "$polygon"
}

# Will return the centered lat,lon point of the relative shape
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
