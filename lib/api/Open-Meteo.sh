openmeteo_data() {
    local csv_file="$1"
    local c_lat c_lon
    local open_meteo_json
    local apparent_temperature humidity
    local wind_speed wind_direction
    local precipitation_mm precipitation_prob cloud_cover
    local hour

    read -r c_lat c_lon <<<"$(calculate_centroid "$csv_file")"

    open_meteo_json=$(curl -sf "https://api.open-meteo.com/v1/forecast?latitude=${c_lat}&longitude=${c_lon}&hourly=precipitation_probability&current=temperature_2m,relative_humidity_2m,precipitation,rain,cloud_cover,wind_speed_10m,wind_direction_10m,apparent_temperature&timezone=auto&forecast_days=1")

    apparent_temperature=$(jq -r '"\(.current.apparent_temperature)\(.current_units.apparent_temperature)"' <<<"$open_meteo_json")
    humidity=$(jq -r '"\(.current.relative_humidity_2m)\(.current_units.relative_humidity_2m)"' <<<"$open_meteo_json")
    wind_speed=$(jq -r '"\(.current.wind_speed_10m)\(.current_units.wind_speed_10m)"' <<<"$open_meteo_json")
    wind_direction=$(jq -r '"\(.current.wind_direction_10m)\(.current_units.wind_direction_10m)"' <<<"$open_meteo_json")
    hour=$(date +%H)
    precipitation_prob=$(jq -r --argjson hour "$hour" '"\(.hourly.precipitation_probability[$hour])\(.hourly_units.precipitation_probability)"' <<<"$open_meteo_json")
    precipitation_mm=$(jq -r '"\(.current.precipitation)\(.current_units.precipitation)"' <<<"$open_meteo_json")
    cloud_cover=$(jq -r '"\(.current.cloud_cover)\(.current_units.cloud_cover)"' <<<"$open_meteo_json")

    i=0
    while ((i < 15)); do
        tput cup $((LINES - 9 - i)) $((COLUMNS / 2))
        printf "%${COLUMNS}s" ' '
        ((i++))
    done

    local lines=(
        "🌡️ $apparent_temperature"
        ""
        "💧 $humidity"
        ""
        "🌬️ $wind_speed, $wind_direction"
        ""
        "☔ $precipitation_prob"
        ""
        "💦 $precipitation_mm"
        ""
        "☁️ $cloud_cover"
    )

    for i in "${!lines[@]}"; do
        tput cup "$(((LINES / 2) + i))" $((COLUMNS / 2 + 2))
        echo "${lines[$i]}"
    done

    tput cup $(((LINES - PIC_H) / 2 + 4)) $((COLUMNS / 2 + 5)) # cursor for zoom
}
