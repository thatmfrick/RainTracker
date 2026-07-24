# RainTracker
A tool for tracking and logging precipitations on a given area powered by 👇

- [Bash](https://www.gnu.org/savannah-checkouts/gnu/bash/manual/bash.html) (Dave Eddy's fault)
- [RainView API](https://www.rainviewer.com/) for fetching precipitations heat maps.
- [jq](https://jqlang.org/) simple queries to RainView's API json.
- [awk](https://docs.rockylinux.org/10/books/sed_awk_grep/4_awk_command/) (math calculi).
- [ImageMagic](https://imagemagick.org/#gsc.tab=0) for image manipulation.
- [Chafa](https://hpjansson.org/chafa/) for printing images in the terminal (just visual).

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/a1176230-b27c-4071-9538-a1dc9cb4dded" />

- RainView API max zoom level is 7 with 512px tiles so i have craked down some math for creating a virtual zoom and for drawing correctly in scale all the given coordinates from a csv file (`tmp.csv`).

- Currently the program will ask for user input via select (gonna change later) regarding parameters like:
  - Image size (256x256, 512x512) is technically possible to go up to 2048x2048 but maybe later...
  - Zoom level (API) 1 to 7
  - Virtual zoom level (y/n) 1 to 10, so total zoom = zoom + virtual zoom
  - Shape:
    - Rectangle: requires only two points (top_left corner, bottom_right corner)
    - Circle: requires oly two points (center point and another one around it to create the radius)
    - Polygon: requires 2+ points (order the points clockwise)

## To-do

- [ ] Extract pixel's color form the designed area and evaluate precipitations probability in the area, or upcoming ones.
- [ ] Improve the TUI
- [ ] Optimize
