// 使用自适应方法产生 y = f(x) 的图象 guide
guide plot(real f(real), real min, real max, int nplotpoints=10, int maxrec=7)
{
    if (nplotpoints < 2)
	nplotpoints = 2;
    // 描初始的 nplotpoints 个点，并估计函数变化幅度
    pair[] fpoints;
    real fmax = -infinity, fmin = infinity;
    for (int i = 0; i <= nplotpoints; ++i) {
	real x = min + i/nplotpoints * (max-min);
	pair z = (x, f(x));
	fmax = max(fmax, z.y);
	fmin = min(fmin, z.y);
	fpoints.push(z);
    }
    // 定义辅助的递归函数：在规定的递归次数之内，在两个样本点之间描新点
    // 误差 fuzz 达到函数变化幅度估计值的 1/500 为止
    // 这个误差值在一般屏幕显示上只有一两个像素
    real fuzz = max(0.002(fmax-fmin), realEpsilon);
    guide helper(int nrec, pair a, pair b)
    {
	if (nrec == 0)
	    return b;
	pair mid = (a+b)/2;
	pair z = (mid.x, f(mid.x));
	if (abs(z.y-mid.y) < fuzz)
	    return z -- b;
	else
	    return helper(nrec-1, a, z) -- helper(nrec-1, z, b);
    }
    // 递归构造 guide
    guide g = fpoints[0];
    for (int i = 0; i < nplotpoints; ++i)
	g = g -- helper(maxrec, fpoints[i], fpoints[i+1]);
    return g;
}



//////////////////////////////////////////

real f(real x) {return 2sin(x^3);}
real min = -5.0, max = 5.0;

// 用自适应方法绘制函数 f(x)
guide g = scale(1cm)*plot(f, min, max);
draw(g, red+1pt);
for (int i = 0; i < size(g); ++i) {
    draw(point(g,i), blue+2pt);
}
write(size(g));


// 用 graph 模块的默认方法（均匀取点）绘制函数 f(x)
import graph;
guide h = shift(-5cm*I)*scale(1cm)*graph(f, min, max);
draw(h, orange+1pt);
for (int i = 0; i < size(h); ++i) {
    draw(point(h,i), blue+2pt);
}
write(size(h));
