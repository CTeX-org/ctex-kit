// 线端（line cap）测试
// milksea

string[] capname = {"squarecap", "roundcap", "extendcap"};
for (int i = 0; i < 3; ++i) {
    path p = shift(0,-i*.5cm) * ((0,0) -- (5cm,0));
    draw(p, linewidth(3mm)+linecap(i)+mediumgray);
    draw(p, linewidth(0.6pt)+squarecap);
    label(Label(capname[i], BeginPoint), p, 2W,
	fontsize(7.5bp/pt)+fontcommand("\ttfamily")); // 六号字
}
