# shellcheck disable=SC2034

RAINVIEWER_API='https://api.rainviewer.com/public/weather-maps.json'
PICTURE_SIZE=512
MIN_LINES=42
MIN_COLS=90
PIC_L=40
PIC_H=22
LOGO_L=75
LOGO_H=4
MENU_L=56
MENU_H=1

GREEN=$'\e[38;5;2m'
WHITE=$'\e[38;5;15m'
RED=$'\e[38;5;1m'
SOFT_BLUE=$'\e[38;2;153;195;255m'
RESET=$'\e[0m'

KOFI='https://ko-fi.com/thatmfrick/tip'
FILE_PROMPT="📄 Select a file: "
FILE_PROMPT_L=$(echo "$FILE_PROMPT" | wc -L)

MENU_LIST="${RED}F${RESET}. Change file    ${RED}Z${RESET}. Change Zoom    ${RED}D${RESET}. Donate    ${RED}Q${RESET}. Quit"
