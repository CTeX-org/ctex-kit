import graph;
size(7cm,0);

real f(real x)
{
    return sin(x)+ 0.1*sin(x*8);
}

xaxis(p=black+linewidth(2mm));
yaxis(p=black+linewidth(2mm));

draw(graph(f,-4,4,operator ..),red+linewidth(2mm)+opacity(0.5));
