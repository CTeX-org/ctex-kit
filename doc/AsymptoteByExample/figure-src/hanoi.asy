struct Peg
{
    private struct Disk
    {
	private int size;

	picture draw(pen p = pink+1mm)
	{
	    picture pic;
	    fill(pic, scale(5mm+size*7.5mm, 4mm)*box((-1/2,-1/2),(1/2,1/2)), p);
	    label(pic, string(size));
	    return pic;
	}
	void operator init(int size)
	{
	    this.size = size;
	}
    }

    private Disk[] disks;
    private string name;

    string getname()
    {
	return name;
    }

    picture draw(pen p = blue+1mm)
    {
	picture pic;
	int n = disks.length;
	fill(pic, box((-2mm, -4mm),(2mm,40mm)), gray);
	fill(pic, box((-4cm, -10mm), (4cm, -4mm)), gray);
	label(pic, name, (0,-5mm), align=down);
	for (int k = 0; k < n; ++k)
	    add(pic, disks[k].draw(), (0,k*5mm));
	return pic;
    }

    void operator init(int n, string name)
    {
	for (int k = n; k > 0; --k)
	    disks.push(Disk(k));
	this.name = name;
    }

    static void transfer(Peg a, Peg b)
    {
	Disk disk = a.disks.pop();
	b.disks.push(disk);
    }
}
from Peg unravel transfer;


import animation;
//usepackage("animate");
//usepackage("movie15");
settings.tex = "pdflatex";

void solvehanoi(int n)
{
    animation ani;
    int step = 0;
    Peg A = Peg(n,"A"), B = Peg(0,"B"), C = Peg(0,"C");

    picture pic;
    add(pic, A.draw().fit(), 0, align=NW);
    add(pic, B.draw().fit(), 0, align=NE);
    add(pic, C.draw().fit(), 0, align=S);
    ani.add(pic);
    void solve(Peg src, Peg dest, Peg mid, int k)
    {
	if (k != 0) {
	    solve(src, mid, dest, k-1);

	    transfer(src, dest);
	    ++step;
	    write(format("%3d: ", step)
		    + src.getname() + " -> " + dest.getname());
	    picture pic;
	    add(pic, A.draw().fit(), 0, align=NW);
	    add(pic, B.draw().fit(), 0, align=NE);
	    add(pic, C.draw().fit(), 0, align=S);
	    ani.add(pic);

	    solve(mid, dest, src, k-1);
	}
    }
    solve(A, B, C, n);
    //label(ani.pdf(delay=500));
    ani.movie(delay=500);
}

solvehanoi(2);
