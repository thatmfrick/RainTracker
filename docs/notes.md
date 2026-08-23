# Some notes (to expand)

Every tile is 256px, at zoom level 7 we will have 2^7 tiles = 128x128 grids so 256*2^7=32768px that will cover the whole world.
2^7 is like the scale.

Now in order to convert a given longitude into a x pixel position: PIXEL_X = MAX_PX * (0.5 + lon / 360).
This (0.5 + lon / 360) will print a value (to 0 to 1) that is representing proportionally where that longitude sits in like a percentage, that longitude is for example 73% of the way across the map, left to right.

Multiplying this by MAX_PX we will get the actual pixel number.

Longitude covers the whole world horizontally from -180 to +180 degrees

lon = -180° -> 0.5 + (-180/360) = 0 (far left edge)
lon = 180° -> 0.5 + (180/360) = 1 (far right edge)
lon = 0° -> 0.5 + (0/365) = 0.5 (center of the map)

in order to calculate the latitude in pixels we have to use this formula that icludes the Mercator stretching function that we divide by 4pi and subtract by 0.5 that squashes the value back to a usable 0-1 fraction (0 = top of the map, 1 = bottom)

y = tile_size * (0.5 - log((1 + siny) / (1 - siny)) / (4 * pi))

siny=sin(lat *pi / 180)




# Math

## [latlon_to_tile](../lib/math.sh)

- n is equal to the ammount of tiles that cover the world at a given zoom z, since the world is represented a a grid `2^z x 2^z`.

- longitude goes from -180 up to 180 so adding 180 will make it's range between 0 and 360, dividing this by 360 will return a value between 0 and 1 that rapresents a fraction of the world. Multiplying this value by n we are scaling that fraction of the world to witch tile column as a float.
- Truncating the value with `int()` will return the actual tile index of the point,meanwhile the leftover fractional part tells where the point sits inside the given tile index.

- For determining the y-tile and y-position in the y-tile of the poin we have to use the **Web Mercator projection formula** due to the fact that latitude on a Mercator map tends to get streched as you approach to the poles.
- `log(tan(lat) + sec(lat))` is the inverse Gudermannian function, the rest of the function just aims to reduce it to a a fraction between 1 (North pole edge) and 0 (south) and than scale it by n.

- Since the tile is standard 256x256 to get the offset of the point inside that tile we have to:
```bash
left_offset = int((x_float-x_tile) * 256)
top_offset = int((y_float - y_tile) * 256)
```

# [WebPage](../lib/web/map.html)

- I will use the Leaflet css' files that are pulled from the internet with pre-made styling for the map widget, buttons, cursors etc...
`<style>#map { height: 100vh; } body { margin: 0; }</style>` is a tiny bit of css customization that will just make the item map fit 100% of the view port height and than removing the page default margin (avoids to have a tiny map box in a corner).
- I create an empty box called `map` that later will be populated by Leaflet JavaScript.
- The rest of the file presents 3 scripts blocks where the first two are only sourced because they contain the logic for displaying the map and the tools:
```html
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<script src="https://unpkg.com/leaflet-draw@1.0.4/dist/leaflet.draw.js"></script>
```
- Than we just tell leaflet to render the map div and adding here the tiles at the given zoom,lat and lon.

- Here we are going to create an empty container/list that will hold whatever shapes get drawn:
```javascript
const drawnItems = new L.FeatureGroup();
map.addLayer(drawnItems);
```

- Than there is the toolbar where the draw object is just a checklist of options enabled or not. `edit: { featureGroup: drawnItems }` tells it "when someone wants to edit/delete an existing shape" to look inside that `drawnItems` container.

- Here we have an event listener that whenever a CREATED event 
```javascript
map.on(L.Draw.Event.CREATED, async (e) => {
        ...
        });
```
