size(200);

pen[] p={red,green,blue,magenta};
pair[] z={(-1,0),(0,0),(0,1),(1,0)};
int[] edges={0,0,0,1};
gouraudshade(z[0]--z[2]--z[3]--cycle,p,z,edges);

draw(z[0]--z[1]--z[2]--cycle);
draw(z[1]--z[3]--z[2],dashed);

dot(Label,z[0],W);
dot(Label,z[1],S);
dot(Label,z[2],N);
dot(Label,z[3],E);

label("0",z[0]--z[1],S,red);
label("1",z[1]--z[2],E,red);
label("2",z[2]--z[0],NW,red);
