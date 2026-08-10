# RainTracker

- A terminal tool for tracking and visualizing precipitation and weather data over a given area.
- Fully written in Bash with the help of:
  - [RainViewer API](https://www.rainviewer.com/) — fetches precipitation heat maps
  - [Open-Meteo](https://open-meteo.com/) - weather data
  - [jq](https://jqlang.org/) — queries RainViewer's and Open-Meteo's JSON responses
  - [awk](https://docs.rockylinux.org/10/books/sed_awk_grep/4_awk_command/) — math calculations
  - [ImageMagick](https://imagemagick.org/) — image manipulation
  - [Chafa](https://hpjansson.org/chafa/) — renders images in the terminal

<img width="1920" height="1080" alt="RainTracker gif" src="https://github.com/user-attachments/assets/4625bdf4-76d2-436a-8125-015ad8ccf828" />

## How it works

RainViewer's API caps out at zoom level 7 with 512px tiles. RainTracker layers some extra math on top of that to provide:

- A **virtual zoom** level beyond RainViewer's native cap
- The ability to draw a scaled area on the map from a simple `.csv` file of `lat,lon` coordinates

- The API refreshes radar images every 10 minutes.

### Usage flow

When run, the program prompts for:

1. **File to load** (read from the config folder)
2. **Location/area name**
3. **Zoom level** — from 1 to 16

### Coordinate file format

| Shape | Points required | Meaning |
|---|---|---|
| Circle | 2 | center point, any point on the radius |
| Polygon | 2+ | vertices, ordered **clockwise** |

## To-do

- [ ] Advanced weather analysis
- [ ] Render a base map beneath the precipitation overlay
- [ ] Add logging
- [ ] Containerize the program
- [ ] Add a non-TUI mode (logging only)
