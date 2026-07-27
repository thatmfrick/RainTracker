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
