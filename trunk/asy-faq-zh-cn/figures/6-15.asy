import graph;
size(250,200,IgnoreAspect);

scale(Linear,Linear(-1));

draw(graph(log,0.1,10),red);

xaxis("$x$",LeftTicks);
yaxis("$y$",RightTicks);

