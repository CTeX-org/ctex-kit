size(0,150);
import geometry;

real a=3;
real b=4;
real c=hypot(a,b);

pair z1=(0,b);
pair z2=(a,0);
pair z3=(a+b,0);
perpendicular(z1,NE,z1--z2,blue);
perpendicular(z3,NW,blue);
draw(square((0,0),z3));
draw(square(z1,z2));

real d=0.3;
pair v=unit(z2-z1);
draw(baseline("$a$"),-d*I--z2-d*I,red,Bars,Arrows,PenMargins);
draw(baseline("$b$"),z2-d*I--z3-d*I,red,Arrows,Bars,PenMargins);
draw("$c$",z3+z2*I-d*v--z2-d*v,red,Arrows,PenMargins);
draw("$a$",z3+d--z3+z2*I+d,red,Arrows,Bars,PenMargins);
draw("$b$",z3+z2*I+d--z3+z3*I+d,red,Arrows,Bars,PenMargins);
