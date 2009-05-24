import graph;

size(10cm);

real f(real x) {return x^2;}

draw(graph(f,-2,2));

xaxis(Ticks(NoZero));
yaxis(Ticks(NoZero));

label("$0$",(0,0),SW);
