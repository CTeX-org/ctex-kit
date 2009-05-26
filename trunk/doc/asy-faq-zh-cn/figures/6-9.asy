import graph;

size(250,200,IgnoreAspect);

draw(graph(exp,-1,1),red);

limits((0,0),(1,2),Crop);

xaxis("$x$",BottomTop,LeftTicks);
yaxis("$y$",LeftRight,RightTicks);

