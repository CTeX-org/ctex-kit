import graph;

size(250,200,IgnoreAspect);

draw(graph(exp,-1,1),red);

xaxis("$x$",BottomTop,LeftTicks);
yaxis("$y$",LeftRight,RightTicks);

fixedscaling((-1.5,-0.5),(1.5,3.5));

