int Width = 600;
int Height = 450;
int LEFT = 30;
int RIGHT = 30;
int TOP = 35;
int BOTTOM = 40;
pen BG = rgb(0.44531, 0.625, 0.80859);
pen FG = rgb(0.33203125, 0.33984375, 0.324121875);
pen TEXT_BG = rgb(255,255,255) + opacity(0.8);
pen BGW = linewidth(16);
pen FGW = linewidth(12);
path OUTLINE = (0,0)--(Width,0)--(Width,Height)--(0, Height)--cycle;
path TEXT_AREA = (LEFT,BOTTOM)--(Width-RIGHT, BOTTOM)--
    (Width-RIGHT,Height-TOP)--(LEFT,Height-TOP)--cycle;
size(Width, Height);

srand(0);
fill(OUTLINE, BG);

path drawRandCircle();
path simpleCircle(pair center, real r);

simpleCircle = new path(pair center, real r)
{
    path temp = (center.x, center.y - r) .. (center.x + r, center.y) .. (center.x, center.y + r) .. (center.x - r, center.y) .. cycle;
    return temp;
};

drawRandCircle = new path()
{
    real Xx = rand() * ((real)(Width) / randMax);
    real Yy = rand() * ((real)(Height) / randMax);
    real R = rand() * (Height/3.0 / randMax);
    path temp = simpleCircle((Xx, Yy), R);
    draw(temp, BG + BGW);
    draw(temp, FG + FGW);
    return temp;
};

path Circle;
for(int i = 0; i <= 15; ++i)
    drawRandCircle();
fill(TEXT_AREA, TEXT_BG);
clip(OUTLINE);
