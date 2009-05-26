//pen operator %(pen p, real x) {return interp(white, p, x/100);}
pen operator %(pen p, real x) {return p + opacity(x/100);}

pen helpline = gray + 0.4;
pen zhu = red + 0.8;
pen huang = yellow + 0.8;

path[] grid(pair z1, pair z2, real xstep = 1, real ystep = xstep)
{
    path[] g;
    pair lb = minbound(z1, z2);
    pair rt = maxbound(z1, z2);
    for (real x = ceil(lb.x/xstep)*xstep; x <= rt.x; x += xstep)
	g.push((x, lb.y) -- (x, rt.y));
    for (real y = ceil(lb.y/ystep)*ystep; y <= rt.y; y += ystep)
	g.push((lb.x, y) -- (rt.x, y));
    return g;
}

unitsize(1cm);
settings.tex = "xelatex";

usepackage("xeCJK");
usepackage("CJKmove");
texpreamble(
"\setCJKmainfont[RawFeature={script=hani:language=CHN:vertical:+valt}]
{FZSongHeiTi_GB18030}
%\XeTeXuseglyphmetrics=0
\setCJKmove{-0.45}{0.5}
\CJKmove
");
defaultpen(fontsize(10.5)); // 五号

Label vert(Label L)
{
    return rotate(-90) * L;
}

draw(grid((0,0), (7,7)), helpline);
draw(shift(4)*rotate(degrees((3,4)))*grid((0,0), (5,5)), helpline);

path huangshi = box((3,3), (4,4));
path[] zhushi = (0,3)--(4,0)--(7,4)--(3,7)--cycle ^^ reverse(huangshi);
filldraw(zhushi, zhu%10, zhu);
fill(huangshi, huang%50);
draw((0,3)--(4,3) ^^ (4,0)--(4,4) ^^ (7,4)--(3,4) ^^ (3,7)--(3,3), zhu);

label(vert("中黃實"), (3.5,3.5), 0.5huang);
label(vert("朱實"), (2,4), right, 0.5zhu);
label(vert("弦實"), (5,4), left, interp(0.5huang,0.5zhu,0.5));
label(Label("句三",MidPoint,Rotate(down)), (4,0)--(4,3), LeftSide);
label(Label("股四",MidPoint,Rotate(left)), (0,3)--(4,3), RightSide);
label(Label("弦五",MidPoint,Rotate((4,-3))), (0,3)--(4,0), LeftSide);

label(vert("朱實六黃實\ 一"), (0,3.5), left, fontsize(14)); // 四号字
label(vert("弦實二十五朱及黃"), (7,3.5), right, fontsize(14));

label(vert("弦圖"), (3.5,7), 4up, fontsize(16));    // 三号字

label(vert(minipage("句股各自乘，併之為弦實，開方除之即弦。
案：弦圖又可以句股相乘為朱實二，倍之為朱實四，
以句股之差自相乘為中黃實，加差實亦成弦實。", 64)), (3.5,0), 4down);

