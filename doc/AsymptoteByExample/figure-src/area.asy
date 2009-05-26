// 一段 Bezier 曲线的面积（相对 x 轴，逆时钟环绕为正）
// 直接利用 S = ∫-y(t)*x'(t) dt 做 0 到 1 的定积分得到
// 其中 z(t) = (x(t), y(t)) = (1-t)^3*z0 + 3t*(1-t)^2*c0 + 3t^2*(1-t)*c1 + t^3*z1
private real area(pair z0, pair c0, pair c1, pair z1)
{
     return (3*c1.y*(z0.x - 2*z1.x) - z0.y*(3*c1.x - 10*z0.x + z1.x)
	- 3*c0.y*(c1.x - 2*z0.x + z1.x) + (6*c1.x + z0.x - 10*z1.x)*z1.y
	+ 3*c0.x*(c1.y - 2*z0.y + z1.y))/20.;
}

// 一条路径的有向面积
// 仅当路径是闭合的时候，有正确的几何意义，此时应具有平移不变性
real area(path[] p)
{
    real A = 0;
    for (path g : p) {
	for (int i = 0; i < length(g); ++i) {
	    pair z0 = point(g, i), z1 = point(g, i+1);
	    pair c0 = postcontrol(g, i), c1 = precontrol(g, i+1);
	    A += area(z0, c0, c1, z1);
	}
    }
    return A;
}


// 应返回 3.14xxx 和 -314.xxx，后面的位不准
write(area(unitcircle));
write(area(reverse(circle((-2,3), 10))));

import graph;
// 应返回 3.14159265358979 和 -314.159265358979，这里 15 位都是准确的
write(area(Circle((0,0), 1)));
write(area(reverse(Circle((-2,3), 10))));

write(area(Circle((0,0), 1, 16)));
write(nCircle);
