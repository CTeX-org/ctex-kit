size(200);
path g = (0,0)..(1,3)..(3,0);
draw(g,Arrow(Relative(0.9)));
add(arrow(g,invisible,FillDraw(black),Relative(0.5)));
add(arrow(reverse(g),invisible,FillDraw(white,black),Relative(0.9)));

