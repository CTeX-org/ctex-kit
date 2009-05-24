arrowhead DotHead;
DotHead.head=new path(path g, position position=EndPoint, pen p=currentpen,
                      real size=0, real angle=0)
{
  if(size == 0) size=DotHead.size(p);
  bool relative=position.relative;
  real position=position.position.x;
  if(relative) position=reltime(g,position);
  path r=subpath(g,position,0.0);
  pair x=point(r,0);
  real t=arctime(r,size);
  pair y=point(r,t);
  return circle(0.5(x+y),0.5size);
};

size(100);
draw((0,0)..(1,1)..(2,0),Arrow(DotHead));
dot((2,0),red);

