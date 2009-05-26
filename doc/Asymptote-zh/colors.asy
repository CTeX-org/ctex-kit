int i=0;
int j=0;

bool components=false;

pen p;

void col(bool fill=false ... string[] s) {
  for(int n=0; n < s.length; ++n) {
    j -= 10;
    string s=s[n];
    eval("p="+s+";",true);
    if(components) {
      real[] a=colors(p);
      for(int i=0; i < a.length; ++i)
        s += " "+(string) a[i];
    }
    if(fill) label(s,(i+10,j),E,p,Fill(gray));
    else label(s,(i+10,j),E,p);
    fill(box((i,j-5),(i+10,j+5)),p);
  }
}

col("palered");
col("lightred");
col("mediumred");
col("red");
col("heavyred");
col("brown");
col("darkbrown");
j -= 10;

col("palegreen");
col("lightgreen");
col("mediumgreen");
col("green");
col("heavygreen");
col("deepgreen");
col("darkgreen");
j -= 10;

col("paleblue");
col("lightblue");
col("mediumblue");
col("blue");
col("heavyblue");
col("deepblue");
col("darkblue");
j -= 10;

i += 150;
j=0;

col("palecyan");
col("lightcyan");
col("mediumcyan");
col("cyan");
col("heavycyan");
col("deepcyan");
col("darkcyan");
j -= 10;

col("pink");
col("lightmagenta");
col("mediummagenta");
col("magenta");
col("heavymagenta");
col("deepmagenta");
col("darkmagenta");
j -= 10;

col("paleyellow");
col("lightyellow");
col("mediumyellow");
col("yellow");
col("lightolive");
col("olive");
col("darkolive");
j -= 10;

col("palegray");
col("lightgray");
col("mediumgray");
col("gray");
col("heavygray");
col("deepgray");
col("darkgray");
j -= 10;

i += 150;
j=0;

col("black");
col("white",fill=true);
j -= 10;

col("orange");
col("fuchsia");
j -= 10;
col("chartreuse");
col("springgreen");
j -= 10;
col("purple");
col("royalblue");
j -= 10;

col("Cyan");
col("Magenta");
col("Yellow");
col("Black");

j -= 10;

col("cmyk(red)");
col("cmyk(blue)");
col("cmyk(green)");
