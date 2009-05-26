real r = 5cm;

draw(circle(0,r), black+1);
dot(0);

path hyperline(pair origin, real r, real deg1, real deg2, bool iscycle=false)
{
    deg1 %= 360;
    deg2 %= 360;
    bool isCCW;
    if (abs(deg1-deg2) == 180) {
	if (iscycle)
	    return shift(origin) * (arc(0, r*dir(deg1), r*dir(deg2)) -- cycle);
	else
	    return shift(origin) * (r*dir(deg1) -- r*dir(deg2));
    }
    if (deg1 > deg2) {
	if (deg1-deg2 > 180) {
	    deg1 -= 360;
	    isCCW = true;
	}
	else
	    isCCW = false;
    }
    else {
	if (deg2-deg1 > 180) {
	    deg2 -= 360;
	    isCCW = false;
	}
	else
	    isCCW = true;
    }

    real delta = isCCW ? deg2-deg1 : deg1-deg2;
    pair z1 = r * dir(deg1), z2 = r * dir(deg2);
    real rad = r/Cos(delta/2);
    pair c = rad * dir((deg1+deg2)/2);
    if (iscycle)
	return shift(origin) *
	    (arc(c, z1, z2, !isCCW) & arc(0, z2, z1, !isCCW)) -- cycle;
    else
	return shift(origin) * arc(c, z1, z2, !isCCW);
}

path[] g1, g2;
for (real t = 30; t <= 180; t += 30) {
    for (real angle = 0; angle < 360; angle += 30) {
	g1.push(hyperline(0, r, angle, angle+t, true));
	g2.push(hyperline(0, r, angle, angle+t, false));
    }
}
fill(g1, evenodd);
draw(g2, orange+0.6);
shipout(bbox(Fill(white)));
