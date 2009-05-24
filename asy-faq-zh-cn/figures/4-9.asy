real u=2cm;

picture square;
draw(square,scale(u)*shift(-0.5,-0.5)*unitsquare);

picture circle;
draw(circle,scale(0.5u)*unitcircle);

void add(picture pic=currentpicture, Label L, picture object, pair z) {
add(pic,object,z);
label(pic,L,z);
}

add("square",square,(0,0));
add("circle",circle,(5cm,0));

