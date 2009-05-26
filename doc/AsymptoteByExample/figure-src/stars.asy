settings.tex = "xelatex";

srand(seconds());

usepackage("xeCJK");
texpreamble(
"\setCJKmainfont{FZSongHeiTi_GB18030}");

Label L =
"\fontsize{16bp}{20bp}\selectfont
\begin{minipage}{3em}
天上星\par
亮晶晶\par
永燦爛\par
長安寧
\end{minipage}";

path unitstar(int n = 5, real r = 0, real angle = 90)
{
    guide g;
    if (n < 2) return nullpath;
    real rot = 180/n;
    if (r == 0) {
	if (n < 5)
	    r = 1/4;
	else
	    r = Cos(2rot) / Cos(rot);
    }
    for (int k = 0; k < n; ++k)
	g = g -- dir(angle+2k*rot) -- r * dir(angle+(2k+1)*rot);
    g = g -- cycle;
    return g;
}

pen operator %(pen p, real x) {return interp(white, p, x/100);}
pen[] colors = {blue%50, yellow%50, red%50, orange%50};
for (int i = 0; i < 100; ++i)
{
    pair pos = (unitrand() * 12cm, unitrand()*9cm);
    int r = rand();
    if (r < randMax/3)
	fill(shift(pos) * scale(2+unitrand()*3) * unitstar(4),
	    colors[rand()%colors.length]);
    else if (r < 2/3*randMax)
	fill(shift(pos) * scale(2+unitrand()*3) * unitstar(5),
	    colors[rand()%colors.length]);
    else
	draw(pos, white+1bp);
}


fill(circle((2cm,8cm),0.5cm), paleyellow);
unfill(circle((1.7cm,7.9cm), 0.5cm));

pair orig=(9cm,0.5cm), end=(1cm,4cm);
path tail = orig{NW} .. {W}end;
path tailN = orig{NW} .. {W}(end+N);
path tailS = orig{NW} .. {W}(end+S);

radialshade(circle(orig, 0.5cm), yellow, orig, 0.1cm, darkblue, orig, 0.5cm);
for (int i = 0; i < 1000; ++i) {
	real t = unitrand()^3;
	real r = (0.2 + t)*cm;
	pair z = point(tail, t) + r*(unitrand()-1/2, unitrand()-1/2);
	draw(z,interp(yellow,white,unitrand())+1bp);
}

label(L, (12cm,9cm), align=SW, yellow, Fill(darkblue+opacity(0.5)));

shipout(bbox(Fill(darkblue)));
