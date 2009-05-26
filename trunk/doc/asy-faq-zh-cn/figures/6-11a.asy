import graph;

size(200,200,IgnoreAspect);

real factorial(real t) {return gamma(t+1);}

scale(Linear,Log);

// Graph the factorial function.
draw(graph(factorial,0,10));

// Method 1: Draw nodes, but hide line
pair F(int t) {return (t,factorial(t));}
// Graph of factorial function from 0 to 10
pair[] z=sequence(F,11);
draw(graph(z),invisible,marker(scale(0.8mm)*unitcircle,blue,Fill,above=true));

// Method 2: Nongraphing routines require explicit scaling:
//pair dotloc(int t) {return Scale(F(t));}
//pair[] dotlocs=sequence(dotloc,11);
//dot(dotlocs);

xaxis("$x$",BottomTop,LeftTicks);
yaxis("$y$",LeftRight,RightTicks);

