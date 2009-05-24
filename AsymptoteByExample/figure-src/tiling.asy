// tiling.asy
// 铺砌图案
// by milksea
import math;
size(15cm);

void sheephead(pair pos, pen color)
{
    path headleft = (0,1.5){SE} .. tension 1.4 .. (0.5,-0.2){dir(-150)} ..
        {NW}(0,0);
    path headbottom = (0,0){SE} .. {dir(30)}(0.5,-0.2) ..{SE}(3,0);
    path head = headleft & headbottom &
        shift(3,0)*reverse(headleft) & shift(0,1.5)*reverse(headbottom) & cycle;

    path eye = circle((2.6,1.2), 0.1);
    path[] ear = (2.3,1.3) .. (2.1,1.5) .. (2.2,1.7)
        & (2.2,1.7) .. (2.4,1.6) .. (2.5,1.4);
    path muzzle = circle((3.5,0.5), 0.15);
    path mouth = (3,0.4) .. (3.4,0.1) .. (3.6,0.2);

    filldraw(shift(pos) * head, color, linewidth(2));
    fill(shift(pos) * (eye ^^ muzzle));
    draw(shift(pos) * (ear ^^ mouth), linewidth(2));
}

for (int i = 0; i < 8; ++i) {
    for (int j = 0; j < 8; ++j) {
        pair pos = (i*3.0, j*1.5);
        pen color = (i+j)%2==0 ? cyan : yellow;
        sheephead(pos, color);
    }
}

clip(ellipse((12,6), 10, 5));
