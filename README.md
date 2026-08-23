# RainTracker

- A terminal tool for tracking and visualizing precipitation and weather data over a given area.
- Fully written in Bash with the help of:
  - [RainViewer API](https://www.rainviewer.com/) — fetches precipitation heat maps
  - [Open-Meteo](https://open-meteo.com/) - weather data
  - [OpenStreetMap-Tiles](https://operations.osmfoundation.org/policies/tiles/)) - tile fetching for background map
  - [Nominatim](https://nominatim.org/release-docs/develop/) - reverse location search
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

coming soon

### Coordinate file format

| Shape | Points required | Meaning |
|---|---|---|
| Polygon | 2+ | vertices, ordered **clockwise** |

## To-do

- [ ] Advanced weather analysis
- [ ] Add logging
