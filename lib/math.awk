function pi() { return atan2(0, -1) }
function radians(x) { return x * (pi() / 180) }
function asin(x) { return atan2(x, sqrt(1.-x*x)) }
function sec(x) { return 1/cos(x) }
function tan(x) { return sin(x) / cos(x) }


# HAVERSINE
function haversine(lat1, lon1, lat2, lon2, 
                   r_earth, dlon, dlat, hav, c, d ) {
    r_earth = 3440.065 #NM

    lon1 = radians(lon1)
    lon2 = radians(lon2)
    lat1 = radians(lat1)
    lat2 = radians(lat2)

    dlon = lon2 - lon1
    dlat = lat2 - lat1

    hav = sin(dlat/2)^2 + cos(lat1) * cos(lat2) * sin(dlon/2)^2

    c = 2 * asin(sqrt(hav))

    d = r_earth * c

    print d
}
# source: https://en.wikipedia.org/wiki/Haversine_formula

#CONVERT LAT/LON TO TILE X,Y WITH POINT OFFSET
function latlon_to_tile(lat, lon, zoom,
                        lat_rad, n, x_float, x_tile, y_float, y_tile, 
                        left_offset, top_offset) {

    lat_rad = radians(lat)
    n = 2^zoom

    x_float = n * (lon + 180) / 360
    x_tile = int(x_float)

    y_float = n * (1 - (log(tan(lat_rad) + sec(lat_rad)) / pi())) / 2
    y_tile = int(y_float)

    left_offset = int((x_float-x_tile) * 256)
    top_offset = int((y_float - y_tile) * 256)

    print x_tile, y_tile, left_offset, top_offset
}
# source: https://wiki.openstreetmap.org/wiki/Slippy_map_tilenames

#WEB MERCATOR PROJECTION
function latlon_to_pixel(lat, lon, zoom, 
                        mapWidth, mapHeight, 
                        FE, radius, lonRad, x, latRad,
                        verticalOffsetFromEquator, y) {

    mapWidth = 256 * 2^zoom
    mapHeight = mapWidth
    FE = 180
    radius = mapWidth / (2 * pi())

    lonRad = radians(lon + FE)
    x = int(lonRad * radius)

    latRad = radians(lat)
    verticalOffsetFromEquator = radius * log(tan(pi()/4 + latRad /2))

    y = int(mapHeight / 2 - verticalOffsetFromEquator)

    print x, y
}
# source: https://medium.com/@suverov.dmitriy/how-to-convert-latitude-and-longitude-coordinates-into-pixel-offsets-8461093cb9f5

#POLYGON CENTROID
function centroid (file, 
                   n, lat, lon, cross,
                   sum_clat, sum_clon, sum_a) {
    n = 0
    while ((getline line < file) > 0) {
        n++ # tricky
        split(line, fields, ",")
        lat[n]=fields[1]
        lon[n]=fields[2]
    }
    close(file)

    for(i=1; i <= n; i++) {
        j = (i % n) + 1
        cross = (lat[i]*lon[j] - lat[j]*lon[i])
        sum_clat += cross * (lat[i] + lat[j])
        sum_clon += cross * (lon[i] + lon[j])
        sum_a += cross
    }

    A = sum_a / 2 
    print sum_clat / (6*A), sum_clon / (6*A)
}
# source: https://www.spatialanalysisonline.com/HTML/centroids_and_centers.htm
# source: https://www.spatialanalysisonline.com/HTML/length_and_area_for_vector_dat.htm

# SCALING ZOOM > 7x
function zoom_calculi(virtual_zoom, pic_size,
                      scale_factor, crop_size,
                      crop_x, crop_y) {
    scale_factor = 2 ^ virtual_zoom
    crop_size = pic_size / scale_factor
    crop_x = (pic_size - crop_size) / 2
    crop_y = (pic_size - crop_size) / 2

    print crop_size, crop_x, crop_y
}
