# RainTracker

A terminal tool for tracking and visualizing precipitation over a given area, powered by:

- [Bash](https://www.gnu.org/savannah-checkouts/gnu/bash/manual/bash.html) — Dave Eddy's fault
- [RainViewer API](https://www.rainviewer.com/) — fetches precipitation heat maps
- [jq](https://jqlang.org/) — queries RainViewer's JSON responses
- [awk](https://docs.rockylinux.org/10/books/sed_awk_grep/4_awk_command/) — math calculations
- [ImageMagick](https://imagemagick.org/) — image manipulation
- [Chafa](https://hpjansson.org/chafa/) — renders images in the terminal

<img width="1110" height="977" alt="RainTracker screenshot" src="https://github.com/user-attachments/assets/2f7e7c76-b024-410c-b303-2cfa17cd92bc" />

## How it works

RainViewer's API caps out at zoom level 7 with 512px tiles. RainTracker layers some extra math on top of that to provide:

- A **virtual zoom** level beyond RainViewer's native cap
- The ability to draw a scaled area on the map from a simple `.csv` file of `lat,lon` coordinates

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

- [ ] Advanced pixel analysis of the selected area for richer info
- [ ] Render a base map beneath the precipitation overlay
- [ ] Polish the TUI (UI & UX)
- [ ] Containerize the program
- [ ] Add a non-TUI mode (logging only)
