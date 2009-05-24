void testline(real y) {
  draw((0,y)--(100,y),currentpen+solid);
  draw((0,y-10)--(100,y-10),currentpen+dotted);
  draw((0,y-20)--(100,y-20),currentpen+dashed);
  draw((0,y-30)--(100,y-30),currentpen+longdashed);
  draw((0,y-40)--(100,y-40),currentpen+dashdotted);
  draw((0,y-50)--(100,y-50),currentpen+longdashdotted);
  draw((0,y-60)--(100,y-60),currentpen+Dotted);
} 

currentpen=linewidth(0.5);
testline(100);

