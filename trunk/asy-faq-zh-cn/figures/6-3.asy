import graph;
size(250,200,IgnoreAspect);

draw(graph(exp,-1,1),red);

xaxis(shift(0,-10)*"$x$",LeftTicks);
yaxis("$y$",RightTicks);

