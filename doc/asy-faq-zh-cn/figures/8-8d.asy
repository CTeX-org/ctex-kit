size(300,300);

path p=(0,0)--(1,0);
picture object;
draw(object,scale(100)*p);

add(object);
add(object,(0,-10)); // Adds truesize object to currentpicture

