import graph;
real[] x={0,1,2,3};
real[] y=x^2;
draw(graph(x,y),red);
xaxis("$x$",BottomTop,LeftTicks);
yaxis("$y$",LeftRight,RightTicks);

size(5cm,5cm,point(SW),point(NE));

label("$f_\mathrm{T}$",point(N),2N);

