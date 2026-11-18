"""Renders the bundled offline world map (assets/map/{z}/{x}_{y}.png).

Low-detail raster tiles, zoom 0-5, with English labels, drawn from Natural
Earth 1:50m data (public domain, https://www.naturalearthdata.com). The app
shows these underneath the online tiles, so the map still works without a
signal.

Usage:
    python tool/render_offline_map.py <natural-earth-dir> assets/map

<natural-earth-dir> holds these unzipped downloads from
https://naciscdn.org/naturalearth/50m/ (one folder each):
    physical/ne_50m_land, physical/ne_50m_lakes,
    cultural/ne_50m_admin_0_boundary_lines_land,
    cultural/ne_50m_admin_0_countries,
    cultural/ne_50m_admin_1_states_provinces_lines,
    cultural/ne_50m_populated_places_simple

Needs Pillow and pyshp. Tiles are 512 px (shown at 256, for sharp
high-DPI screens).
"""
import math
import os
import sys

import shapefile
from PIL import Image, ImageDraw, ImageFont

MAX_ZOOM = 5
TILE = 512
CHUNK = 8192  # draw the world in pieces this big, then cut tiles
FONT = '/System/Library/Fonts/Supplemental/Arial.ttf'
FONT_BOLD = '/System/Library/Fonts/Supplemental/Arial Bold.ttf'

OCEAN = (170, 211, 223)
LAND = (242, 239, 233)
BORDER = (150, 135, 160)
STATE = (190, 180, 195)
COUNTRY_TEXT = (110, 100, 115)
CITY_TEXT = (40, 40, 40)
HALO = (255, 255, 255)

# US states, Canadian provinces, Australian states: worth showing for
# grid-square hunting. Other countries' internal lines would just be clutter.
STATE_COUNTRIES = {'USA', 'CAN', 'AUS', 'MEX', 'BRA', 'RUS'}


def read(ne, name):
    for root, _, files in os.walk(ne):
        if name + '.shp' in files:
            return shapefile.Reader(os.path.join(root, name))
    sys.exit(f'missing {name} in {ne}')


def project(lon, lat, size):
    lat = max(min(lat, 85.0511), -85.0511)
    x = (lon + 180.0) / 360.0 * size
    r = math.radians(lat)
    y = (1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) / 2 * size
    return x, y


def parts(shape):
    idx = list(shape.parts) + [len(shape.points)]
    for a, b in zip(idx, idx[1:]):
        yield shape.points[a:b]


class Layer:
    """Shapes projected for one zoom, with pixel bounding boxes for culling."""

    def __init__(self, shapes, size):
        self.items = []
        for s in shapes:
            for p in parts(s):
                pts = [project(lon, lat, size) for lon, lat in p]
                xs = [q[0] for q in pts]
                ys = [q[1] for q in pts]
                self.items.append((pts, (min(xs), min(ys), max(xs), max(ys))))

    def within(self, box):
        x0, y0, x1, y1 = box
        for pts, (a, b, c, d) in self.items:
            if c >= x0 and a <= x1 and d >= y0 and b <= y1:
                yield pts


def place_labels(z, size, countries, places):
    """Picks labels for zoom z, biggest first, dropping any that overlap."""
    scale = TILE / 256
    taken = []
    out = []

    def free(box):
        for t in taken:
            if box[0] < t[2] and box[2] > t[0] and box[1] < t[3] and box[3] > t[1]:
                return False
        return True

    measure = ImageDraw.Draw(Image.new('L', (1, 1)))

    # Countries: Natural Earth's MIN_LABEL says from which zoom a label fits.
    cfont = ImageFont.truetype(FONT_BOLD, int((10 if z < 3 else 12) * scale))
    for rec in sorted(countries, key=lambda r: (r['LABELRANK'], r['MIN_LABEL'])):
        if rec['MIN_LABEL'] > z + 1.5:
            continue
        name = (rec['NAME_EN'] or rec['NAME']).upper()
        if z < 3 and len(name) > 14:
            name = (rec['ABBREV'] or name).upper().rstrip('.')
        x, y = project(rec['LABEL_X'], rec['LABEL_Y'], size)
        l, t, r, b = measure.textbbox((x, y), name, font=cfont, anchor='mm')
        box = (l - 4, t - 4, r + 4, b + 4)
        if free(box):
            taken.append(box)
            out.append(('country', name, x, y, cfont, box))

    # Cities, largest first.
    pfont = ImageFont.truetype(FONT, int((10 if z < 4 else 11) * scale))
    limit = {0: 0, 1: 0, 2: 2.5, 3: 3.6, 4: 4.6, 5: 5.6}[z]
    dot = 3 * scale
    for rec in sorted(places, key=lambda r: (r['scalerank'], -r['pop_max'])):
        if rec['min_zoom'] > limit:
            continue
        name = rec['name']
        x, y = project(rec['lon'], rec['lat'], size)
        l, t, r, b = measure.textbbox((x + dot + 3, y), name, font=pfont, anchor='lm')
        box = (x - dot - 2, min(t, y - dot) - 3, r + 3, max(b, y + dot) + 3)
        if free(box):
            taken.append(box)
            out.append(('city', name, x, y, pfont, box))
    return out


def render_zoom(z, data, outdir):
    size = TILE * (2 ** z)
    scale = TILE / 256
    land = Layer(data['land'], size)
    lakes = Layer([s for s, r in data['lakes'] if r['scalerank'] <= z + 1], size)
    borders = Layer(data['borders'], size)
    states = Layer([s for s, r in data['states']
                    if r['ADM0_A3'] in STATE_COUNTRIES and z >= 3], size)
    labels = place_labels(z, size, data['countries'], data['places'])

    border_w = max(1, round((0.8 + 0.25 * z) * scale))
    state_w = max(1, round((0.5 + 0.12 * z) * scale))
    chunk = min(size, CHUNK)
    count = 0
    for oy in range(0, size, chunk):
        for ox in range(0, size, chunk):
            box = (ox - 20, oy - 20, ox + chunk + 20, oy + chunk + 20)
            img = Image.new('RGB', (chunk, chunk), OCEAN)
            d = ImageDraw.Draw(img)

            def shift(pts):
                return [(x - ox, y - oy) for x, y in pts]

            for pts in land.within(box):
                if len(pts) > 2:
                    d.polygon(shift(pts), fill=LAND)
            for pts in lakes.within(box):
                if len(pts) > 2:
                    d.polygon(shift(pts), fill=OCEAN)
            for pts in states.within(box):
                d.line(shift(pts), fill=STATE, width=state_w, joint='curve')
            for pts in borders.within(box):
                d.line(shift(pts), fill=BORDER, width=border_w, joint='curve')

            for kind, name, x, y, font, (l, t, r, b) in labels:
                if r < box[0] or l > box[2] or b < box[1] or t > box[3]:
                    continue
                x, y = x - ox, y - oy
                if kind == 'country':
                    d.text((x, y), name, font=font, anchor='mm', fill=COUNTRY_TEXT,
                           stroke_width=int(2 * scale), stroke_fill=HALO)
                else:
                    rad = 3 * scale
                    d.ellipse((x - rad, y - rad, x + rad, y + rad), fill=HALO,
                              outline=CITY_TEXT, width=max(1, int(scale)))
                    d.text((x + rad + 3, y), name, font=font, anchor='lm', fill=CITY_TEXT,
                           stroke_width=int(2 * scale), stroke_fill=HALO)

            for ty in range(chunk // TILE):
                for tx in range(chunk // TILE):
                    tile = img.crop((tx * TILE, ty * TILE, (tx + 1) * TILE, (ty + 1) * TILE))
                    x = ox // TILE + tx
                    y = oy // TILE + ty
                    path = os.path.join(outdir, str(z), f'{x}_{y}.png')
                    tile.quantize(colors=64, method=Image.Quantize.MEDIANCUT) \
                        .save(path, optimize=True)
                    count += 1
    return count


def main():
    ne, outdir = sys.argv[1], sys.argv[2]
    countries_r = read(ne, 'ne_50m_admin_0_countries')
    places_r = read(ne, 'ne_50m_populated_places_simple')
    pf = [f[0] for f in places_r.fields[1:]]
    places = []
    for s, rec in zip(places_r.shapes(), places_r.records()):
        r = dict(zip(pf, rec))
        r['lon'], r['lat'] = s.points[0]
        places.append(r)
    cf = [f[0] for f in countries_r.fields[1:]]
    data = {
        'land': read(ne, 'ne_50m_land').shapes(),
        'lakes': list(zip(read(ne, 'ne_50m_lakes').shapes(),
                          [dict(zip([f[0] for f in read(ne, 'ne_50m_lakes').fields[1:]], r))
                           for r in read(ne, 'ne_50m_lakes').records()])),
        'borders': read(ne, 'ne_50m_admin_0_boundary_lines_land').shapes(),
        'states': list(zip(read(ne, 'ne_50m_admin_1_states_provinces_lines').shapes(),
                           [dict(zip([f[0] for f in read(ne, 'ne_50m_admin_1_states_provinces_lines').fields[1:]], r))
                            for r in read(ne, 'ne_50m_admin_1_states_provinces_lines').records()])),
        'countries': [dict(zip(cf, r)) for r in countries_r.records()],
        'places': places,
    }
    for z in range(MAX_ZOOM + 1):
        os.makedirs(os.path.join(outdir, str(z)), exist_ok=True)
        print(f'zoom {z}: {render_zoom(z, data, outdir)} tiles')


if __name__ == '__main__':
    main()
