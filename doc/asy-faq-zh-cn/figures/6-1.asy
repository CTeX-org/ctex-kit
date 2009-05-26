import graph;

size(250,200,IgnoreAspect);

draw(graph(exp,-1,1),red);

xaxis("$x$",RightTicks(Label(align=left)));
yaxis("$y$",RightTicks);

