# RainTracker
A tool for tracking and logging precipitations on a given area powered by 👇

- [Bash](https://www.gnu.org/savannah-checkouts/gnu/bash/manual/bash.html) (Dave Eddy's fault)
- [RainView API](https://www.rainviewer.com/) for fetching precipitations heat maps.
- [jq](https://jqlang.org/) simple queries to RainView's API json.
- [awk](https://docs.rockylinux.org/10/books/sed_awk_grep/4_awk_command/) (math calculi).
- [ImageMagic](https://imagemagick.org/#gsc.tab=0) for image manipulation.
- [Chafa](https://hpjansson.org/chafa/) for printing images in the terminal (just visual).

<img width="1920" height="1078" alt="image" src="https://github.com/user-attachments/assets/a6ae5d39-2fd7-4acf-807b-36cc1a69d0c9" />

- RainView API max zoom level is 7 with 512px tiles.
- With some math I have created an higher zoom level called "virtual zoom" and also the possibly to draw (in scale) a given area starting from a simple `.csv` file filled with `lat,lon` (latitude and longitude) values.

- Currently the program will ask to the user:

  - File to load (stored inside config folder)
  - Relative shape of the area (circle or rectange) in case only two coordinates are passed otherwise it will auto detect a polygon.
    
    - Regarding the coordinates in the `.csv` file:
      - Rectangle: requires only two points (top_left corner, bottom_right corner)
      - Circle: requires only two points (center point and another one around it to create the radius)
      - Polygon: requires 2+ points (order the points clockwise)

  - Zoom level 1 to 16

## To-do

- [ ] Advanced pixel analysis in the given area for providing more informations.
- [ ] Try to add a map below the area.
- [ ] Improve the TUI both UI&UX.
- [ ] Containerize the program.
- [ ] Create a non-tui version (just logging).
