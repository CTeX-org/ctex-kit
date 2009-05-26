unitsize(1cm);
path g = ellipse((0,0), 4, 1);
axialshade(g, green, (-4,0), yellow, (4,0));
axialshade(shift(0,-2.5)*g, stroke=true,
           green+linewidth(2mm), (-4,0), yellow, (4,0));
