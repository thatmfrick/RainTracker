# RainTracker
A tool for tracking and logging precipitations on a given area using:

- Bash (Dave Eddy's fault)
- [RainView API](https://www.rainviewer.com/) for fetching precipitations heat maps.
- awk (math calculi).
- [ImageMagic](https://imagemagick.org/#gsc.tab=0) for image manipulation.
- [Chafa](https://hpjansson.org/chafa/) for printing images in the terminal (just visual).

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/a1176230-b27c-4071-9538-a1dc9cb4dded" />

- RainView API max zoom level is 7 with 512px tiles so i have craked down some math for creating a virtual zoom and for drawing correctly in scale all the given coordinates from a csv file.
- It's possible (not yet implemented) to create different shapes like circles, squares and polygons for tracking every kind of zone.

## To-do

- [ ] Extract pixel's color form the designed area and evaluate precipitations probability in the area, or upcoming ones.
- [ ] Improve the TUI
- [ ] Optimize
