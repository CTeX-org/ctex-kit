fill((0,0)--(100,100)--(200,0)--cycle);

pair center(picture pic=currentpicture) {return 0.5*(pic.min()+pic.max());}

real height=100;
real width=100;
pair delta=0.5(width,height);
pair c=center();
clip(box(c-delta,c+delta));

