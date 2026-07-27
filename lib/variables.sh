RAINVIEWER_API='https://api.rainviewer.com/public/weather-maps.json'
PICTURE_SIZE=512
GREEN=$'\e[38;5;2m'
WHITE=$'\e[38;5;15m'
RED=$'\e[38;5;1m'
SOFT_BLUE=$'\e[38;2;153;195;255m'
RESET=$'\e[0m'
MENU=

IFS= read -d '' -r LOGO <<"EOF" || true
  ▄▄▄▄▄▄                 ▄▄▄▄▄▄▄                                                 
 █▀██▀▀▀█▄              █▀▀██▀▀▀▀                                           █▄   
   ██▄▄▄█▀        ▀▀ ▄     ██   ▄                ▄▄           ▄             ██   
   ██▀▀█▄   ▄▀▀█▄ ██ ████▄ ██   ████▄▄▀▀█▄ ▄███▀ ██ ▄█▀ ▄█▀█▄ ████▄   ▄██▀█ ████▄
 ▄ ██  ██   ▄█▀██ ██ ██ ██ ██   ██   ▄█▀██ ██    ████   ██▄█▀ ██      ▀███▄ ██ ██
 ▀██▀  ▀██▀▄▀█▄██▄██▄██ ▀█ ▀██▄▄█▀  ▄▀█▄██▄▀███▄▄██ ▀█▄▄▀█▄▄▄▄█▀  ██ █▄▄██▀▄██ ██ 
EOF

IFS= read -d '' -r MENU_LIST <<EOF || true
${RED}F${RESET}. Select File

${RED}Z${RESET}. Change Zoom
EOF
