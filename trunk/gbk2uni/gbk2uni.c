/*  $Id: gbk2uni.c,v 1.3 2005/03/21 02:44:41 zlb Exp $ */
/*   */
/*  gbk2uni.cpp : Transform GBK characters in .out file to unicode codes. */
/*      the initial code is from out2uni in dvipdfmx project of KTUG */
/*  authors:  cxterm and Linbo Zhang in 2003 */
/*  reach them at http://www.ctex.org */
/*  enhancer: hooklee (Shujun Li) in 2003 */
/*  reach hooklee at http://www.hooklee.com or www.chinatex.org */

/* ===================================================== */
/* ********************hyperref书签文件编码规则************************** */
/* 每个书签以如下形式存放 :\BOOKMARK [1][-]{section.0.1}{书签正文}{} */
/* 非unicode模式下使用hyperref宏包，bookmark中的部分特殊字符以\ooo的形式插入 */
/* ' ':\040, '#':\043, '$':\044, '%':\045, '&':\046, '\':\134, '^':\136, '_':\137, '{':\173, '}':\175, '~':176 */
/* 比较特殊的是'('和')'，是以'\('和'\)'的形式插入的，而不是\ooo形式 */
/* \S:\247 */
/* 所有其他字符和汉字均不作任何处理，在bookmark中保留 */
/* 已经知道，这种保留会造成部分汉字在bookmark中无法显示 */
/* 当使用\CJKchar{"0081}{"040}方式直接以GBK代码的方法插入汉字，bookmark中会生成如下的书签代码： */
/* "0081"040，显然，pdflatex忽略了\CJKchar命令本身和前后的{}把参数当做普通文本做了转换 */
/* '^^xx^^yy'形式的CJK汉字在.out中有两种可能的出现方式：'^^xx^^yy'和'^^xxL' */
/* ===================================================== */
/* unicode模式下使用hyperref宏包，bookmark特殊字符均编码为\ooo\ooo或者\000x或者\000x\80y形式的unicode代码 */
/* 书签内容均以\376\377开头作为前导标示符 */
/* 经过实验，相应的bookmarkunicode代码插入规则如下： */
/* *****A类：编码为\ooo\ooo的特殊字符部分***** */
/* ' '(空格):\000\040，使用\textvisiblespace也得到同样的书签 */
/* '#'(\#):\000\043, '$'(\$):\000\044, '%'(\%):\000\045, '&'(\&):\000\046 */
/* '(':\000\050; ')':\000\051 */
/* '\'(\textbackslash):\000\134; */
/* '^'(\textasciicircum):\000\136; '_'(\_):\000\137 */
/* '{'(\{):\000\173; '}'(\}):\000\175 */
/* '~'(\textasciitilde):\000\176; */
/* *****B类：编码为\000x的普通字符部分，其中x表示字符本身***** */
/* abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 */
/* |:',./!?;"-+=[]`*@(直接用@即可，无需\@)<(或\textless)>(或\textgreater) */
/* *****C类：单个汉字***** */
/* 假设其高位码为H，低位码为L，则一般的GB汉字其插入形式为：\000H\80L */
/* 但是上述情况存在例外，当L为普通拉丁字符时，将会以\000HL的形式插入 */
/* 如果任何汉字出现在一个低位为拉丁字符的GBK汉字之后，第二个汉字会以\80H\000L的形式出现 */
/* 只有\80HL是不可能出现的汉字代码 */
/* 当书签中包含多个汉字的时候，重复按照上述规则插入，汉字中间的其他字符按照正常规则插入 */
/* ===================================================== */
/* @注意：当汉字低位字节为字符'}{~\_^'时，tex文档编译会出现错误，强行编译可能出现不可预测的行为 */
/* @插入out文件的内容变得很混乱，一般书签正文会在低位'}'出现之后终止，gbk2uni只尽可能地消除这种影响 */
/* @这可能使得部分GBK汉字在书签中消失或者显示为其他字符 */
/* @使用张林波老师随CCT新版发行的cctconv程序可以解决这个问题 */
/* @cctconv把汉字低位字节为'\', '{', '}', '^', '_', '~'的汉字低位字节分别改为'012345'以方便处理 */
/* @或者使用-f开关转换可以将所有高位为1的字符转换为^^xx的形式，这在一些老的不支持扩展字符的tex系统中有用 */
/* @gbk2uni处理这样的汉字假设cctconv已经运行（cctconv与CJK兼容，无需cct.sty即可得到正确的dvi文件） */
/* @这样的汉字经cctconv处理后，插入out文件的对应内容在unicode模式下有两种可能： */
/* @sprintf("\\000%d\\%03o", H, L)和sprintf("%d\\%03o", H, L)，这里L已经是被转换回来的'}{~\_^' */
/* 现在还不清楚是否也有sprintf("\\80%d\\%03o", H, L)形式出现（根据'\80HL'不出现推测这种形式可能也不出现） */
/* ===================================================== */
/* *****D类：\CJKchar{"00ab}{"0cd}形式的CJK汉字***** */
/* \000"\0000\0000\000a\000b\000"\0000\000c\000d */
/* 显然，unicode模式的hyperref是如下工作的： */
/* 第一步先生成非unicode模式的out文件，接着对其中的扩展字符做了一个后处理，但是这个处理对汉字不正确 */
/* *****E类：'^^xx^^yy'形式的CJK汉字***** */
/* 在unicode模式下，.out文件的内容一般为'\000^^xx\80^^yy'或者'\000^^xx\80L' */
/* 估计其他CJK汉字的样式也可能出现：'\80^^xx\000^^yy'、'\80^^xx\000L'、'\000^^xx^^yy'、'\000^^xx\ooo' */
/* 以上情况说明，在处理过程中，我们可以像TeX那样将每一个'^^xx'码字当成普通的ASCII字符来处理即可兼容'^^xx'代码 */
/* ===================================================== */
/* 如果\CJKchar{}{}中的前后两个参数位数不同，单从.out文件无法判断第二个参数何时结束 */
/* 因此，gbk2uni要求在tex文档中统一采用三位十六进制法\CJKchar{"0xx"}{"0xx}表示前后两个参数 */
/* 考虑到在实际中\CJKchar用的比较少，这个约定应该不会算大的限制。 */
/* ===================================================== */

#define VERSION "0.22"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#if defined(WIN32) && !defined(__MINGW32__)
#  include <io.h>
#  define PATH_MAX	_MAX_PATH+1
#else
#  include <unistd.h>
#  include <limits.h>
#endif

#include "gbk2uni.h"

#ifndef WIN32
#  define _fileno(f) f
static size_t _filelength(FILE *f)
{
    size_t pos = ftell(f);
    size_t length;

    fseek(f, 0, SEEK_END);
    length = ftell(f);
    fseek(f, pos, SEEK_SET);
    return length;
}
#endif

#if !defined(WIN32) && !defined(GO32)
static int strnicmp (const char *s0, const char *s1, int n)
{
    int i;
    while (n-- > 0 && *s0 != '\0' && *s1 != '\0') {
	i = toupper(*(s0++)) - toupper(*(s1++));
	if (i) return i;
    }
    return n > 0 ? toupper(*s0) - toupper(*s1) : 0;
}
#endif

#define BYTE unsigned char
#define DWORD unsigned int

/* is a valid high byte of some GBK character */
#define GBK_HIGH(h)  ((0x81<=(h&0xff)) && ((h&0xff)<=0xfe))

/* is a valid low byte of some GBK character */
#define GBK_LOW(l)  ((0x40<=(l&0xff)) && ((l&0xff)<=0xfe))

int		bLock = 0;/* lock  */
int		bUnlockOnly = 0;
int		bCJKchar = 1;/* enable \CJKchar support defaultly, disable it with '-nc' option */
/* int		bIgnoreCJK7 = 0; */
int		bParsingErrors = 1;
/* int		bVerbose = 0; */
int		bSilent = 0;
FILE   *Fout;
FILE   *Fin;

void version(void)
{
  printf("gbk2uni, version "VERSION", initially implemented by cxterm and ZLB in Jan. 2003\n");
  printf("\t enhanced by hooklee in Mar. 2003.\n");
  printf("\t please visit www.ctex.org and www.chinatex.org for more information.\n");
}

/* print usage of gbk2uni */
void usage(void)
{
  version();
  printf("Usage : gbk2uni [options] filename[.out] [options]\n");
  printf("Options:\n");
  printf("\t-u(-l)\t lock .out file to avoid overwritten in the next (pdf)latex run\n");
  printf("\t\t (.out file will be unlocked if no '-u' and '-l' options)\n");
  printf("\t-unlock\t unlock .out file without parsing .out file\n");
/*   printf("\t-i\t ignore all CJK characters with \"^^xx^^yy\" format\n"); */
  printf("\t-s\t run gbk2uni silently (but errors remain)\n");
  printf("\t-cjk\t parse \\CJKchar{\"0xx}{\"0xx} command (default)\n");
  printf("\t-nocjk\t disable parsing \\CJKchar{\"0xx}{\"0xx} command\n");
  printf("\t-npe\t disable display of all parsing errors\n");
}

/* write unicode into the file Fout */
void putucode(unsigned int u)
{
  unsigned int h, l;

  l = u & 0xff;
  h = (u >> 8) & 0xff;

  fprintf(Fout,"%c%03o%c%03o",'\\',h,'\\',l);
}

/* put a GBK code */
void putGBKcode(BYTE h, BYTE l,int nLine)
{
	unsigned int u;
	unsigned int hu, lu;

	if (!GBK_HIGH(h) || !GBK_LOW(l)) {
		/* if current GBK character is not valid, it will be discarded */
		if (bParsingErrors)
			fprintf (stderr, "An invalid GBK character is found:\n\tLine %d: ... 0x%x%x\n", nLine, h,l);
		return;
	}

	u = gbk2uni[(h-0x81)*192 + (l-0x40)];
	lu = u & 0xff;
	hu = (u >> 8) & 0xff;
	fprintf(Fout,"\\%03o\\%03o",hu,lu);
}

/* is a character c '0'...'9','a'...'f','A'...'F'? */
int is8digit(char c)
{
	return (c>='0' && c<='7') ? 1 : 0;
}

/* is a character c '0'...'9','a'...'f','A'...'F'? */
int is16digit(char c)
{
	return (isdigit(c)) || (c>='a' && c<='f') || (c>='A' && c<='F') ? 1 : 0;
}

/* 3-digit octal string to decimal number */
unsigned char otoi(char *str)
{
	return 64*(*str-'0') + 8*(*(str+1)-'0') + (*(str+2)-'0');
}

/* 2-digit hexadecimal string to decimal number */
unsigned char xtoi(char *str)
{
	unsigned char h,l;
	h = (unsigned char)tolower(*str);
	l = (unsigned char)tolower(*(str+1));
	if (isdigit(h)) h = h - '0';
	else h = h - 'a' + 10;
	if (isdigit(l)) l = l - '0';
	else l = l - 'a' + 10;
	return 16*h + l;
}

/* parse '\000"\000x\000x' generated by \CJKchar{}{} command */
/* this function is used to skip the leading string '\000' */
int getCJKchar(char **str,int nLine)
{
	int i;

	while(**str!='\\' && **str != '\0' && **str != '}') (*str)++;/* find the next '\\' */
	if (**str == '}' || **str == '\0') return 0;
	(*str)++;
	for (i=0; i < 3; i++) {
		if(**str != '0') break;
		(*str)++;
	}
	if (i != 3) {
		if (bParsingErrors)
			fprintf (stderr, "An incomplete \\CJKchar{}{} command is found:\n\tLine %d: ... \"%s\"\n", nLine, (*str)-i-1);
		return -1;
	}
	return 1;
}

/* translate a '^^xx'-format TeX character to an ascii character */
/* if not a '^^xx'-format TeX character, return itself */
int translateChar(char **str,int nLine)
{
	BYTE a;

	if ( **str != '^') {
		a = **str;
		if ( **str != '}' && **str != '\0' ) (*str)++;
		return a;/* if not '^^xx' directly return the current character */
	}

	while(**str == '^') (*str)++;/* skip all '^' characters */
	if ( is16digit(**str) && is16digit(*(*str+1)) ) {
		a = xtoi(*str);
		(*str) = *str + 2;
		return a;
	}
	else {
		if (bParsingErrors)
			fprintf (stderr, "An incomplete '^^xx' TeX character is found:\n\tLine %d: ... \"%s\"\n", nLine, (*str)-2);
		return -1;/* -1L = 0xffffffff */
	}
}

/* parse the bookmark and generate corresponding unicode codes */
char *doparse(char *str,BYTE bUnicode,int nLine)
{
	BYTE	lh,h,l;/* h denotes high byte and l denotes low byte of a unicode character,lh denotes the leading '\ooo' */
	int		i, rtn;
	char	strCode[4];

	/* skip to the next valid character... needed or not? */
	while(1) {
		if(bUnicode)
			while(*str==' ' || *str=='\t' || *str=='\n' || *str=='\r') str++;
		else
			while(*str=='\t' || *str=='\n' || *str=='\r') str++;
		
		if ( *str == '}' || *str == '\0') return str;/* end */

		switch(*str) {
		case '\\':
			/* original unicode codes generated by pdflatex, including '\(' and '\)' */
			/* note: '\oo' and '\par' may occur in wrongly-complied tex document */
			while(*str == '\\') str++;/* occasionally double '\' may occur in a wrong .out file */
			/* processing '\ooo' in non-unicode mode */
			if(!bUnicode) {
				/* processing '\(' and '\)' in non-unicode */
				if ( *str == '(' || *str == ')') {
					fprintf(Fout,"\\000\\%03o", *str++);
					break;
				}
				/* in non-unicode mode, '\ooo' is possible for special latin character, such as '\S' */
				if (isdigit(*str)) {
					fprintf(Fout,"\\000\\");/* add '\000' prefix to current special unicode character */
					i=0;
					while(1) {
						fputc(*str++,Fout);i++;
						if(!isdigit(*str) || i >=3) break;
					}/* to avoid less than three digital characters after '\' */
					/* fwrite(Fount,1,3,str);str+=3; */
					if ( i < 3 && bParsingErrors)
						fprintf (stderr, "An incomplete special character is found:\n\tLine %d: ... \"%s\"\n", nLine, str-i-1);
				}
				break;
			}
			/* processing '\ooo\ooo' or '\000x' or '\000H\80L' or '\000HL' or '\80H\000L' in unicode mode */
			/* here please note that either 'H' or 'L' or both two can be '^^xx'-format */
			if (isdigit(*str)) {
				/* in unicode mode, '\ooo\ooo' and '\000x' and '\000H\80L' are all possible for different characters */
				/* possibly, '\oo' should be taken into consideration to avoid possible collapse of gbk2uni */
				strCode[0]=*str++;
				for (i=1; i<3; i++) {
					if(isdigit(*str)) strCode[i]=*str++;
					else break;
				}
				strCode[i]='\0';
				if (i == 1) {
					if (bParsingErrors)
						fprintf (stderr, "An incomplete special unicode code is found:\n\tLine %d: ... \"%s\"\n", nLine, str-i-1);
					break;
				}
				lh = atoi(strCode);/* get the high byte of current unicode character */
				if(i ==3 && *str == '\\') {/* '\ooo\ooo': normal unicode character */
					fprintf(Fout, "\\%s\\", strCode);/* directly output leading '\ooo\' */
					str++;
					for (i=0; i<3; i++) {
						if(isdigit(*str)) strCode[i]=*str++;/* directly output the left 'ooo' */
						else break;
					}
					strCode[i]='\0';
					if (i < 3) {
						if (bParsingErrors)
							fprintf (stderr, "An incomplete unicode code is found:\n\tLine %d: ... \"%s\"\n", nLine, str-i-1);
					}
					else fprintf(Fout, "%s", strCode);/* directly output the left 'ooo' */
					break;
				}
				if (lh == 0 && *str == '\"' && bCJKchar) {/* \CJKchar{"0xx}{"0xx} command in unicode mode */
					rtn = getCJKchar (&str, nLine);
					if(rtn == 0) return str;
					if(rtn == -1) break;/* skip the first '\0000' */
					rtn = getCJKchar (&str, nLine);
					if(rtn == 0) return str;
					if(rtn == -1) break;
					strCode[0] = *str++;/* get the first digit of high byte */
					rtn = getCJKchar (&str, nLine);
					if(rtn == 0) return str;
					if(rtn == -1) break;
					strCode[1] = *str++;/* get the second digit of high byte */
					h = xtoi (strCode);/* get high byte */

					rtn = getCJKchar (&str, nLine);
					if(rtn == 0) return str;
					if(rtn == -1) break;
					if (*str != '\"') {/* is the third unicode code '"'? */
						if (bParsingErrors)
							fprintf (stderr, "An incomplete \\CJKchar{}{} command is found:\n\tLine %d: ... \"%s\"\n", nLine, str-4);
						break;
					}
					rtn = getCJKchar (&str, nLine);
					if(rtn == 0) return str;
					if(rtn == -1) break;/* skip the second '\0000' */
					rtn = getCJKchar (&str, nLine);
					if(rtn == 0) return str;
					if(rtn == -1) break;
					strCode[0] = *str++;/* get the first digit of low byte */
					rtn = getCJKchar (&str, nLine);
					if(rtn == 0) return str;
					if(rtn == -1) break;
					strCode[1] = *str++;/* get the second digit of low byte */
					l = xtoi (strCode);/* get low byte */
					putGBKcode(h, l, nLine);/* put unicode code via GBK2UNICODE transformation */
					break;
				}
				/* '\000x' or '\000H\80L' or '\80H\000L' or '\000H\ooo' */
				rtn = translateChar(&str,nLine);
				if (rtn == -1) break;/* break when encountering errors */
				else h = (BYTE) rtn;
				if (lh == 0 && h != 0 && h != '}' && h < 0x80) {/* '\000x' format remains */
					/* translate '\000x' to '\000\ooo' to get more robust result */
					fprintf(Fout, "\\000\\%03o", h);
					break;
				}
				if (lh == 0 && h > 0x80) {/* '\000HL' or '\000H\80L' or '\000H\ooo' */
					/* h = (BYTE) *str++;*/ /*set high GBK byte */
					if ( *str != '\\') {/* '\000HL' */
						rtn = translateChar(&str,nLine);
						if (rtn == -1) break;/* break when encountering errors */
						else l = (BYTE) rtn;
						/* l = *str++; */
						putGBKcode(h, l, nLine);/* put unicode code via GBK2UNICODE transformation */
					}
					else {/* '\000H\80L' or '\000H\ooo' */
						if (*(str+1) == '8' && *(str+2) == '0') {/*  is '80L' after '\'? */
							str += 3;
							rtn = translateChar(&str,nLine);
							if (rtn == -1) break;/* break when encountering errors */
							else l = (BYTE) rtn;
							/* l = *str++;*/ /*set low GBK byte */
							putGBKcode(h, l, nLine);/* put unicode code via GBK2UNICODE transformation */
						}
						else if ( is8digit(*(str+1)) && is8digit(*(str+2)) && is8digit(*(str+3)) ) {
							l = otoi(str+1);
							putGBKcode(h, l, nLine);/* put a GBK code */
#if 0
							if (l == '{' || l == '}' || l == '\\' || l == '^' || l == '_' || l == '~' || l == 0x80)
								putGBKcode(h, l, nLine);/* put a GBK code */
							else if (bParsingErrors)
								fprintf (stderr, "An invalid GBK character (in cctconv format) is found:\n\tLine %d: ... \"%s\"\n", nLine, str-i-2);
#endif
							str += 4;
						}
						else if (bParsingErrors)
							fprintf (stderr, "An incomplete GBK character is found:\n\tLine %d: ... \"%s\"\n", nLine, str-i-1);
					}
					break;
				}
				if (lh == 80 && h > 0x80) {/* '\80H\000L' */
					/* h = (BYTE) *str++;*/ /*set high GBK byte */
					if (*str == '\\' && *(str+1) == '0' && *(str+2) == '0' && *(str+3) == '0') {/*  is '\000L' after '\80H'? */
						str += 4;
						rtn = translateChar(&str,nLine);
						if (rtn == -1) break;/* break when encountering errors */
						else l = (BYTE) rtn;
						/* l = *str++;*/ /*set low GBK byte */
						putGBKcode(h, l, nLine);/* put unicode code via GBK2UNICODE transformation */
					}
					else if (bParsingErrors)
						fprintf (stderr, "An incomplete GBK character is found:\n\tLine %d: ... \"%s\"\n", nLine, str-i-1);
					break;
				}
				if (h == 80 && *str > 0) {/* is '\80x' possible? */
					if(*str != '}' && *str != '\0') str++;/* goto the next code */
				}
				break;
			}
			/* remove '\par' from .out file */
			if(*str == 'p' && *(str+1) == 'a' && *(str+2) == 'r') str+=3;
			break;
#if 0
		case '^':/* GBK characters with CJK format '^^xx^^yy' */
			while(*str=='^') str++;/* skip all '^' characters */
			if (is16digit(*str) && is16digit(*(str+1))) {
				h = xtoi(str); str += 2;
				while(*str=='^') str++;/* skip all '^' characters */
				if (is16digit(*str) && is16digit(*(str+1))) {
					l = xtoi(str); str += 2;
					if (!bIgnoreCJK7) putGBKcode(h, l, nLine);/* put a GBK code if not ignoring */
				}
				else if (*str < 0)
				else if (bParsingErrors)
					fprintf (stderr, "An incomplete GBK character (in CJK format) is found:\n\tLine %d: ... \"^^%s\"\n", nLine, str-2);
			}
			else if (bParsingErrors)
				fprintf (stderr, "An incomplete GBK character (in CJK format) is found:\n\tLine %d: ... \"^^%s\"\n", nLine, str);
			break;
#endif
		case '\"':/* \CJKchar{"0xx}{"0xx} command in non-unicode mode? */
			if (!bCJKchar) fprintf(Fout, "\\000\\%03o", *str++);/* normal '"' character in non-unicode mode */
			else {/* \CJKchar{"0xx}{"0xx} command in non-unicode mode */
				while(*str=='\"') str++;/* skip all '"' characters */
				if (*str == '0') str++;/* skip the first '0' */
				if (is16digit(*str) && is16digit(*(str+1))) {
					h = xtoi(str); str += 2;
					while(*str=='\"') str++;/* skip all '"' characters */
					if (*str == '0') str++;/* skip the second '0' */
					if (is16digit(*str) && is16digit(*(str+1))) {
						l = xtoi(str); str += 2;
						putGBKcode(h, l, nLine);/* put a GBK code */
					}
					else if (bParsingErrors)
						fprintf (stderr, "An incomplete GBK character (in \\CJKchar{}{} format) is found:\n\tLine %d: ... \"%s\"\n", nLine, str-2);
				}
				else if (bParsingErrors)
					fprintf (stderr, "An incomplete GBK character (in \\CJKchar{}{} format) is found:\n\tLine %d: ... \"%s\"\n", nLine, str);
			}
			break;
		default:/* normal characters in non-unicode mode or cctconv GBK characters in both mode */
			    /* or '^^xx^^yy'/'^^xxL' TeX characters */
			rtn = translateChar(&str,nLine);
			if (rtn == -1) break;/* break when encountering errors */
			else h = (BYTE) rtn;
			if (h != 0 && h != '}' && h < 0x80) fprintf(Fout, "\\000\\%03o", h);/* normal latin character */
			else {/* GBK character */
				/* h = *str++;*/ /*GBK high byte */
				if (*str == '\\') {/* characters generated by cctconv  */
					str++;
					for(i = 0; i < 3; i++) {
						if(is8digit(*str)) strCode[i] = *str++;
						else break;
					}
					strCode[i] = '\0';
					if ( i != 3) {
						if (bParsingErrors)
							fprintf (stderr, "An incomplete GBK character (in cctconv format) is found:\n\tLine %d: ... \"%s\"\n", nLine, str-i-2);
						break;
					}
					l = otoi(strCode);/* get low byte from '\ooo' */
					putGBKcode(h, l, nLine);/* put a GBK code */
#if 0
					if (l == '{' || l == '}' || l == '\\' || l == '^' || l == '_' || l == '~')
						putGBKcode(h, l, nLine);/* put a GBK code */
					else if (bParsingErrors)
						fprintf (stderr, "An invalid GBK character (in cctconv format) is found:\n\tLine %d: ... \"%s\"\n", nLine, str-i-2);
#endif
					break;
				}
				/* low byte of a normal CJK character or '^^yy' */
				rtn = translateChar(&str,nLine);
				if (rtn == -1) break;/* break when encountering errors */
				else l = (BYTE) rtn;
				switch(l) {
					case '}':
					case '\0': 
						if (bParsingErrors)
							fprintf (stderr, "An incomplete GBK character (in '^^xx^^yy' format) is found:\n\tLine %d: ... \"%s\"\n", nLine, str);
						return str;/* SHOULD exit when reading '\0' or '}' */
					case '0': l = '\\'; break;/* reserved for future CCT */
					case '1': l = '{';  break;/* reserved for future CCT */
					case '2': l = '}';  break;/* reserved for future CCT */
					case '3': l = '^';  break;/* reserved for future CCT */
					case '4': l = '_';  break;/* reserved for future CCT */
					case '5': l = '~';  break;/* reserved for future CCT */
					case '6': l = 0x80; break;/* reserved for future CCT */
					case '7': l = '|'; break;/* reserved for future CCT */
					default: ;/* normal GBK character or '^^yy' */
				}
				putGBKcode(h, l, nLine);/* put a GBK code */
				/* str++; */
			}
		}
	}
}

int main(int argc, char* argv[])
{
  char          inname[PATH_MAX]="";
  char          outname[PATH_MAX]="";
  char          bakname[PATH_MAX]="";
  char          *p;
  unsigned int	nLength;
  char         *b_in,*b2_in,*b3_in;
  BYTE			bUnicode=0;
  int			nLine, i;

  for(i=1; i < argc; i++) {
#if defined(WIN32) || defined(GO32)
	  strlwr(argv[i]);
#endif
	  if (!strcmp(argv[i], "-u") || !strcmp(argv[i], "-l")) {
		  bLock = 1; if (bUnlockOnly) bUnlockOnly = 0;
	  }
/* 	  else if (!strcmp(argv[i], "-i")) bIgnoreCJK7 = 1; */
/* 	  else if (!strcmp(argv[i], "-v")) bVerbose = 1; */
	  else if (!strcmp(argv[i], "-s")) bSilent = 1;
	  else if (!strcmp(argv[i], "-cjk")) bCJKchar = 1;
	  else if (!strcmp(argv[i], "-nocjk")) bCJKchar = 0;
	  else if (!strcmp(argv[i], "-unlock")) {
		  bUnlockOnly = 1; if (bLock) bLock = 0;
	  }
	  else if (!strcmp(argv[i], "-npe")) bParsingErrors = 0;
	  else strcpy(inname, argv[i]);
  }

  if(inname[0] == '\0') {
    usage();
    return 1;
  }

  if (!bSilent) version();/* display version and developer information */

  p = strrchr(inname, '.');
#ifdef WIN32
  if((p == NULL) || stricmp(p, ".out")) strcat(inname, ".out");
#else
  if((p == NULL) || strcmp(p, ".out")) strcat(inname, ".out");
#endif

  strcpy(outname, inname);
  strcat(outname, ".tmp");

  Fin = fopen(inname, "r");
  if(!Fin) {
    fprintf(stderr, "Cannot open %s to read!\n", inname);
    exit(1);
  }
  nLength = _filelength (_fileno(Fin));
  if (nLength <= 0) {
    fprintf(stderr, "Cannot get the file size of %s!\n", inname);
	fclose (Fin); exit(1);
  }

  Fout = fopen(outname, "wt");
  if(!Fout) {
    fprintf(stderr, "Cannot open %s to write!\n", outname);
    fclose (Fin); exit(1);
  }

  b_in = (char *) malloc(nLength);
  if(!b_in) {
    fprintf(stderr, "Memory allocation error!\n");
    fclose (Fin); fclose (Fout); exit (2);
  }

  if(bLock) {
    fprintf(Fout,"\\let\\WriteBookmarks\\relax\n");
  }

  nLine = 0;
  while(!feof(Fin))
  {
	  if (fgets(b_in, nLength, Fin) == NULL) break;
	  nLine++;
	  /* if '\let\WriteBookmarks\relax' is found, skip the current line */
	  if (strstr(b_in,"\\let\\WriteBookmarks\\relax\n")) continue;
	  if (bUnlockOnly) {/* only unlock .out file when '-unlock' option is set */
		  fputs(b_in, Fout);
		  continue;
	  }
	  b2_in = b_in;
      while( (*b2_in==' ' || *b2_in=='\n' || *b2_in=='\r' || *b2_in=='\t') && *b2_in!='\0' ) b2_in++;
	  if ( *b2_in == '\0') {
/* 		  if (bParsingErrors) */
/* 			fprintf(stderr, "Warning: No bookmark content is found:\n\tLine %d: \"%s\"\n", nLine, b_in); */
/* 		  fputs(b_in,Fout);*/ /* simply copy the wong line into new .out file */
		  continue;
	  }
	  if (strnicmp(b2_in, "\\BOOKMARK",9)) {/* skip invalid line in .out file */
		  if (bParsingErrors)
			fprintf(stderr, "Invalid line is found:\n\tLine %d: \"%s\"\n", nLine, b_in);
/* 		  fputs(b_in,Fout);*/ /* simply copy the wong line into new .out file */
		  continue;
	  }
	  /* find the position of the second parentheses */
	  /* '{' and '}' are displayed as '\173' and '\175' in .out file */
	  /* so there is no nested parentheses */
      while(*b2_in!='}' && *b2_in!='\0' && *b2_in!='\n' && *b2_in!='\r' && *b2_in!='\t') b2_in++;
	  while(*b2_in!='{' && *b2_in!='\0' && *b2_in!='\n' && *b2_in!='\r' && *b2_in!='\t') b2_in++;
	  if ( *b2_in == '\0') {
		  if (bParsingErrors)
			fprintf(stderr, "Warning: No bookmark content is found:\n\tLine %d: \"%s\"\n", nLine, b_in);
/* 		  fputs(b_in,Fout);*/ /* simply copy the wong line into new .out file */
		  continue;
	  }
	  b2_in ++;
	  fwrite ( b_in, 1, b2_in-b_in, Fout);/* copy the left part of the new line */
	  /* Set unicode flag and skip the leading characters if encountering '\376\377' */
	  if( !strncmp(b2_in, "\\376\\377", 8) ) {
		  b2_in += 8; bUnicode = 1;
	  }
	  fputs("\\376\\377",Fout);/* set .out file to unicode format in non-unicode mode */
	  b3_in=doparse(b2_in, bUnicode, nLine);/* parse the middle part and write the new unicode codes */
	  fputs(b3_in,Fout);/* copy the right part of the new line */
  }

  free (b_in);
  fclose(Fin);
  fclose(Fout);

  sprintf(bakname, "%s.bak",inname);
  remove(bakname);
  rename(inname,bakname);
  rename(outname,inname);

  if (!bSilent) fprintf(stdout, "gbk2uni %s is finished!\n",inname);

/*   getchar(); */
  return 0;

}

