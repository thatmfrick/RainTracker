openmeteo_data() {

    local csv_file="$1"

    local c_lat c_lon
    read -r c_lat c_lon <<<"$(awk -f lib/math.awk -v file="$csv_file" -e 'BEGIN { print centroid(file) }')"

    local daily_meteo_json
    daily_meteo_json=$(curl -sf "https://api.open-meteo.com/v1/forecast?latitude=$c_lat&longitude=$c_lon&daily=rain_sum,temperature_2m_min,temperature_2m_max&hourly=precipitation_probability&models=best_match&current=relative_humidity_2m,apparent_temperature,cloud_cover,wind_speed_10m,wind_direction_10m,temperature_2m,precipitation,snowfall,showers,rain&timezone=auto&forecast_days=1")

    local elevation
    elevation="$(jq -r '.elevation' <<<"$daily_meteo_json")m"

    local hour
    hour=$(date +%H)
    precipitation_prob=$(jq -r --argjson hour "$hour" '"\(.hourly.precipitation_probability[$hour])\(.hourly_units.precipitation_probability)"' <<<"$daily_meteo_json")

    local temperature_2m_max
    temperature_2m_max=$(jq -r '"\(.daily.temperature_2m_max[])\(.daily_units.temperature_2m_max)"')

    local temperature_2m_min
    temperature_2m_min=$(jq -r '"\(.daily.temperature_2m_min[])\(.daily_units.temperature_2m_min)"')

    local rain_sum
    rain_sum=$(jq -r '"\(.daily.rain_sum[])\(.daily_units.rain_sum)"')

    local temperature_2m
    temperature_2m=$(jq -r '"\(.current.temperature_2m)\(.current_units.temperature_2m)"' <<<"$daily_meteo_json")

    local relative_humidity_2m
    relative_humidity_2m=$(jq -r '"\(.current.relative_humidity_2m)\(.current_units.relative_humidity_2m)"' <<<"$daily_meteo_json")

    local wind_speed_10m
    wind_speed_10m=$(jq -r '"\(.current.wind_speed_10m)\(.current_units.wind_speed_10m)"' <<<"$daily_meteo_json")

    local wind_direction_10m
    wind_direction_10m=$(jq -r '"\(.current.wind_direction_10m)\(.current_units.wind_direction_10m)"' <<<"$daily_meteo_json")

    local cloud_cover
    cloud_cover=$(jq -r '"\(.current.cloud_cover)\(.current_units.cloud_cover)"' <<<"$daily_meteo_json")

    local precipitation
    precipitation_mm=$(jq -r '"\(.current.precipitation)\(.current_units.precipitation)"' <<<"$daily_meteo_json")

    local rain
    rain=$(jq -r '"\(.current.rain)\(.current_units.rain)"' <<<"$daily_meteo_json")

    local snowfall
    snowfall=$(jq -r '"\(.current.rain)\(.current_units.snowfall)"' <<<"$daily_meteo_json")

    local showers
    showers=$(jq -r '"\(.current.rain)\(.current_units.showers)"' <<<"$daily_meteo_json")

    i=0
    while ((i < 15)); do
        tput cup $((LINES - 9 - i)) $((COLUMNS / 2))
        printf "%${COLUMNS}s" ' '
        ((i++))
    done

    local lines=(
        "🌡️ $temperature_2m"
        ""
        "💧 $relative_humidity_2m"
        ""
        "🌬️ $wind_speed_10m, $wind_direction_10m"
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
