import sys, numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage
src, out = sys.argv[1], sys.argv[2]
im = Image.open(src).convert('RGB')
g = im.convert('L')
bg = np.asarray(g.filter(ImageFilter.MaxFilter(9)), float)
px = np.asarray(g, float)
a = np.asarray(im, int)
diff = bg - px
# not green (cover / waves): green channel dominates strongly
greenish = (a[...,1] - a[...,0] > 30)
dark = (diff > 35) & ~greenish
region = np.zeros_like(dark); region[350:900, 175:850] = True
dark &= region
lab, n = ndimage.label(dark, structure=np.ones((3,3)))
keep = np.zeros_like(dark)
for i, sl in enumerate(ndimage.find_objects(lab), 1):
    h = sl[0].stop - sl[0].start; w = sl[1].stop - sl[1].start
    if h > 120 or w > 360: continue          # page outlines / gutter
    keep |= (lab == i)
keep = ndimage.binary_dilation(keep, iterations=1)
alpha = np.clip(diff * 2.2, 0, 255) * keep
Image.fromarray(alpha.astype(np.uint8), 'L').save(out)
print(n, 'components')
