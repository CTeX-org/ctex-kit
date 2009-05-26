// labelalign.asy
// 在路径上标注的标签 Label 的 position 和 align 参数示例
// milksea
// 2009-02-20

// XeLaTeX 中文设置
texpreamble("\input{fzfonts.tex}");

// pdfTeX 中文设置
// usepackage("ctexutf8");
// texpreamble("\pdfpkresolution2400"); // 如果使用 pk 字体，用较高精度。

usepackage("asycolors");
size(0,100);

defaultpen(fontsize(7.5bp/pt));
pen alignpen = heavyblue;
pen pospen = heavygreen;

path p = (0,0) .. tension 1.1 .. (1,1) .. tension 0.9 .. (2,0);
draw(p, brown+1);


real len = length(p);
for (int i = 0; i <= len; ++i) {
    label(Label(format("%d",i), position=i), p, pospen);
    draw(point(p,i)+rotate(-90)*0.02dir(p,i) -- point(p,i)+rotate(90)*0.02dir(p,i), pospen);
}
label(Label("\tt Relative(0.5)=MidPoint", MidPoint, NE), p, pospen);
draw(midpoint(p)+rotate(-90)*0.02dir(p,reltime(p,1/2))
    -- midpoint(p)+rotate(90)*0.02dir(p,reltime(p,1/2)), pospen);


pair d = relpoint(p, 0.8);

draw(Label("\tt Relative(0.8)",BeginPoint), d+0.1NE -- d, pospen);
//label(Label("弧长相对位置", Relative(0.8), 10NE), p, pospen);

label(Label("\tt N", Relative(0.8), 2N), p, alignpen);
label(Label("\tt S", Relative(0.8), 2S), p, alignpen);
label(Label("\tt W", Relative(0.8), 2W), p, alignpen);
label(Label("\tt E", Relative(0.8), 2E), p, alignpen);
//label(Label("绝对对齐方位", Relative(0.8), 6S, Fill(white+opacity(0.7))), p, alignpen);
dot(d,red);



pair c = point(p,0.5);

draw(Label("0.5",BeginPoint), c+0.1N -- c, pospen);
//label(Label("时间参数绝对位置", position=0.5, 2W+10N), p, pospen);

draw(Label("相对北极轴",position=EndPoint,align=Relative(N),Fill(white+opacity(0.7))),
     c--c+0.3dir(p,0.5), alignpen+linewidth(0.6), Arrow);
label(Label("\tt LeftSide", position=0.5, 2LeftSide), p, alignpen);
label(Label("\tt RightSide", position=0.5, 2RightSide), p, alignpen);
label(Label("\tt Relative(S)", position=0.5, 2Relative(S), Rotate(dir(p,0.5)), Fill(white+opacity(0.7))), p, alignpen);
//label(Label("相对对齐方位", 0.5, 2E + 10S), p, alignpen);

dot(c,red);


label(minipage("\centering 使用~\texttt{Label}~函数在路径上标注\\\texttt{\color{heavygreen}position}~和~\texttt{\color{heavyblue}align}~参数示意", 5cm), (1,0));
