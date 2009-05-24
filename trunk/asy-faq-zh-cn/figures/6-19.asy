import graph;
size(10cm,0);
pair[] z={(0,0),(0.5,0.5),(1,1)};
path g=graph(z);

draw(shift(0,.5)*g,marker(scale(5)*unitcircle,FillDraw(white)));

xaxis(BottomTop,LeftTicks);
yaxis(LeftRight,RightTicks);

