picture pic;
path C1 = circle((0,0), 1cm), C2 = circle((1cm,0), 1cm);
fill(C1, paleblue);         draw(pic, C2, linewidth(2mm));
fill(pic, C1, heavyblue);   clip(pic, C2);
add(pic);
