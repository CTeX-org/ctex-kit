size(200);

real mexican(real x) {return (1-8x^2)*exp(-(4x^2));}

int n=30;
real a=1.5;
real width=2a/n;

guide hat;
path solved;

for(int i=0; i < n; ++i) {
  real t=-a+i*width;
  pair z=(t,mexican(t));
  hat=hat..z;
  solved=solved..z;
}

draw(hat);
dot(hat,red);
draw(solved,dashed);

