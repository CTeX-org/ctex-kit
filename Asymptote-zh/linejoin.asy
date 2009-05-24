// 线连接（line join）测试
// milksea

string[] capname = {"miterjoin", "roundjoin", "beveljoin"};
for (int i = 0; i < 3; ++i) {
    path p = shift(i*3cm,0) * ((0,0) -- (-1cm,.5cm) -- (0,1cm));
    draw(p, linewidth(3mm)+linejoin(i)+mediumgray);
    draw(p, linewidth(0.6pt)+squarecap);
    label(Label(capname[i], MidPoint), p, 4W,
	fontsize(7.5bp/pt)+fontcommand("\ttfamily")); // 六号字
}
