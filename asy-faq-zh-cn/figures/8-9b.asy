size(200,100);
fill((0,0)--(1,1)--(2,0)--cycle);

void clip(picture pic=currentpicture, real width, real height)
{
pic.clip(new void (frame f, transform) {
pair center=0.5(min(f)+max(f));
pair delta=0.5(width,height);
clip(f,box(center-delta,center+delta));
});
}

clip(100,100);

