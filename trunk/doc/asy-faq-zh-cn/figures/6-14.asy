import graph;

real width=15cm;
real aspect=0.3;

picture pic1,pic2;

size(pic1,width,aspect*width,IgnoreAspect);
size(pic2,width,aspect*width,IgnoreAspect);

scale(pic1,false);
scale(pic2,false);

real xmin1=6;
real xmax1=9;
real xmin2=8;
real xmax2=16;

real a1=1;
real a2=0.001;

real f1(real x) {return a1*sin(x/2*pi);}
real f2(real x) {return a2*sin(x/4*pi);}

draw(pic1,graph(pic1,f1,xmin1,xmax1));
draw(pic2,graph(pic2,f2,xmin2,xmax2));

xaxis(pic1,Bottom,LeftTicks());
yaxis(pic1,"$f_1(x)$",Left,RightTicks);

xaxis(pic2,"$x$",Bottom,LeftTicks(Step=4));
yaxis(pic2,"$f_2(x)$",Left,RightTicks);

yequals(pic1,0,Dotted);
yequals(pic2,0,Dotted);

pair min1=point(pic1,SW);
pair max1=point(pic1,NE);

pair min2=point(pic2,SW);
pair max2=point(pic2,NE);

real scale=(max1.x-min1.x)/(max2.x-min2.x);
real shift=min1.x/scale-min2.x;

transform t1=pic1.calculateTransform();
transform t2=pic2.calculateTransform();
transform T=xscale(scale*t1.xx)*yscale(t2.yy);

add(pic1.fit());
real height=truepoint(N).y-truepoint(S).y;
add(shift(0,-height)*(shift(shift)*pic2).fit(T));

