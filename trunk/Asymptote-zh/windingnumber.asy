path p2 =
(-89,2)..controls(-86.8188470497,44.0983279574)and(-45.9938314745,72.3882023306)..(-2,69)
..controls(37.3564255309,65.9689493222)and(71.1986829486,38.501250568)..(76,0)
..controls(81.6314985122,-45.1583873691)and(46.3165401516,-84.2754685726)..(0,-92)
..controls(-60.1996040054,-102.039906511)and(-116.438157081,-59.1028090769)..(-116,0)
..controls(-115.569614418,58.0545150815)and(-60.8290914438,99.2504221041)..(0,97)
..controls(56.1281494698,94.923493098)and(100.064478245,53.1265690797)..(102,0)
..controls(107.052588053,-138.684397375)and(-95.2410532598,-118.458268134)..cycle;

import fontsize;
defaultpen(linewidth(1.5));

// XeLaTeX 设置
texpreamble("\input{fzfonts.tex}");

// pdfTeX 设置
// usepackage("ctexutf8");
// texpreamble("\pdfpkresolution2400"); // 如果使用 pk 字体，用较高精度。

picture windpic(int windnum, path p ... int[] patition)
{
    picture pic;
    dot(pic, (0,0), linewidth(4pt));
    label(pic, "\LARGE$\hbox{卷绕数}="+string(windnum)+"$", (0,0), 3S);
    patition.insert(0,0);
    int n = patition.length;
    for (int i = 0; i < n-1; ++i)
	draw(pic, subpath(p, patition[i], patition[i+1]), heavyred, Arrow(TeXHead));
    draw(pic, subpath(p, patition[n-1], length(p)), heavyred);
    return pic;
}

add(currentpicture, windpic(-2, p2, 2, 6).fit(), (0,0), 10W);
add(currentpicture, windpic(-1, scale(100)*(N..E..S..W..cycle), 1).fit(), (0,0), 10E);
add(currentpicture, windpic(0, shift(80,0)*scale(50)*(N..E..S..W..cycle), 1).fit(), (200,0), 40E);
add(currentpicture, windpic(1, scale(100)*(S..E..N..W..cycle), 1).fit(), (450,0), 20E);
add(currentpicture, windpic(2, reverse(p2), 1, 5).fit(), (700,0), 10E);

add(bbox(xmargin=10,ymargin=0,p=invisible));

