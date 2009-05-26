size(400);
pair z0=(0,0);
pair c0=(1,1);
pair c1=(2,1);
pair z1=(3,0);
draw(z0..controls c0 and c1 .. z1,blue);

draw(z0--c0--c1--z1,dashed);
dot("$z_0$",z0,W,red);
dot("$c_0$",c0,NW,red);
dot("$c_1$",c1,NE,red);
dot("$z_1$",z1,red);
