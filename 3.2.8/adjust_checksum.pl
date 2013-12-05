eval '(exit $?0)' && eval 'exec perl -S $0 ${1+"$@"}' && eval 'exec perl -S $0 $argv:q'
  if 0;
use strict;
$^W=1; # turn warning on
#
# adjust_checksum.pl
#
# Copyright (C) 2006-2011 by Heiko Oberdiek <heiko.oberdiek at googlemail.com>
#
# This work may be distributed and/or modified under the
# conditions of the LaTeX Project Public License, either
# version 1.3 of this license or (at your option) any later
# version. The latest version of this license is in
#    http://www.latex-project.org/lppl.txt
# and version 1.3 or later is part of all distributions of
# LaTeX version 2003/12/01 or later.
#
# This work has the LPPL maintenance status "maintained".
#
# This Current Maintainer of this work is Heiko Oberdiek.
#
# This work consists of this file.
#
# This file "adjust_checksum.pl" may be renamed to "adjust_checksum"
# for installation purposes.
#
my $file        = "adjust_checksum.pl";
my $program     = uc($&) if $file =~ /^\w+/;
my $version     = "1.5";
my $date        = "2011/04/15";
my $author      = "Heiko Oberdiek";
my $copyright   = "Copyright (c) 2002, 2006-2011 by $author.";
#
# Reqirements: Perl5, Windows
# History:
#   2002/03/15 v1.0: First release.
#   2006/02/12 v1.1: Fix for \Checksum{0}.
#   2007/06/15 v1.2: -draftmode added.
#   2007/09/25 v1.3: ltxdoc.cfg added to speed up.
#   2008/07/16 v1.4: Use of package `syntonly' for speed.
#   2011/04/15 v1.5: Email address updated.
#

my $prg_latex = "xelatex -no-pdf";

my $tempdir = "tmp_\L$program\E_$$";

### program identification
my $title = "$program $version, $date - $copyright\n";

my $usage = <<"END_OF_USAGE";
${title}Syntax: \L$program\E <file.dtx>
Function: Correction of "\\CheckSum{...}" entry in <file.dtx>.
END_OF_USAGE

### error strings
my $Error = "!!! Error:"; # error prefix

### parse command line arguments
@ARGV == 1 or die $usage;
my $dtxfile = $ARGV[0];

print $title;

### check dtx file
-f $dtxfile or die "$Error File not found: '$dtxfile'!\n";

### signals
$SIG{__DIE__} = \&clean;
$SIG{'HUP'}   = \&clean;
$SIG{'INT'}   = \&clean;
$SIG{'QUIT'}  = \&clean;
$SIG{'TERM'}  = \&clean;

### make temp dir
mkdir $tempdir;
-d $tempdir or die "$Error Cannot create directory '$tempdir'!\n";

### copy dtx file
my $tempdtxfile = $dtxfile;
$tempdtxfile =~ s/.*\///;
my $latexfile = $tempdtxfile;
$tempdtxfile = $tempdir . "/" . $tempdtxfile;

sub win32 {
  return ($^O =~ /^MSWin/i) ? 1 : 0;
}

&win32 ? system("copy /y $dtxfile $tempdir > nul") :
         system("cp $dtxfile $tempdtxfile");
-f $tempdtxfile or die "$Error Cannot copy dtx file!\n";

### create l3doc.cfg
my $ltxdocfile = $tempdir . "/" . 'l3doc.cfg';
open(OUT, '>', $ltxdocfile)
        or die "!!! Error: Cannot open file `$ltxdocfile'!\n";
print OUT <<'__END__LTXDOC_CFG__';
\typeout{* version for adjust_checksum}
\AtEndOfClass{%
  \DontCheckModules
  \DisableCrossrefs
  \def\DisableCrossrefs{\@bsphack\@esphack}%
  \let\EnableCrossrefs\DisableCrossrefs
  \let\CodelineIndex\relax
  \let\PageIndex\relax
  \let\CodelineNumbered\relax
  \let\PrintChanges\relax
  \let\PrintIndex\relax
  \let\tableofcontents\relax
  \PassOptionsToPackage{bookmarks=false}{hyperref}%
  \expandafter\xdef\csname ver@hypdoc.sty\endcsname{}%
  \expandafter\xdef\csname ver@bmhydoc.sty\endcsname{}%
  \nofiles
  \hfuzz\maxdimen
  \pretolerance10000 %
  \tolerance10000 %
  \DisableDocumentation
  \usepackage{syntonly}%
  \AtBeginDocument{\syntaxonly\XeTeXinterchartokenstate=\z@}%
}
\endinput
__END__LTXDOC_CFG__
close(OUT);

### run latex
print "*** Running XeLaTeX ...\n";
my $nulldev = &win32 ? "nul" : "/dev/null";
system("($prg_latex -interaction=batchmode -output-directory=$tempdir $tempdtxfile > $nulldev)");

my $logfile = $tempdtxfile;
$logfile =~ s/\.[^\.]+$//;
$logfile .= ".log";
-f $logfile or die "$Error Cannot find log file '$logfile'!\n";

### parse log file for CheckSum
print "*** Looking for checksum statement ...\n";
my $found = 0;
my $changed = 0;
my $old = 0;
my $new = 0;
open(LOG, $logfile) or die "$Error Cannot open log file '$logfile'!\n";
while (<LOG>) {
  if (/\* Checksum passed \*/) {
    $found = 1;
    $changed = 0;
    print "==> Checksum passed.\n";
    last;
  }
  if (/Checksum not passed \((\d+)<>(\d+)\)/) {
    $found = 1;
    $changed = 1;
    $old = $1;
    $new = $2;
    last;
  }
  if (/The checksum should be (\d+)!/) {
    $found = 1;
    $changed = 1;
    $old = 0;
    $new = $1;
    last;
  }
}
close(LOG);

$found or die "$Error Checksum statement not found in log file!\n";

if ($changed) {
  print "==> Checksum not passed ($old<>$new).\n";

  ### write changed dtx file
  print "*** Fixing Checksum ...\n";
  my $fixed = 0;
  open(IN, $tempdtxfile) or die "$Error Cannot open '$tempdtxfile'!\n";
  open(OUT, ">$dtxfile") or die "$Error Cannot write '$dtxfile'!\n";
  while (<IN>) {
    if (s/\\CheckSum\{\d+\}/\\CheckSum{$new}/) {
      $fixed++;
      print "==> Checksum fixed:\n$_";
    }
    print OUT;
  }
  close(IN);
  close(OUT);

  $fixed > 0 or
      die "$Error: \"\\CheckSum{...}\" not found!\n";
  $fixed == 1 or
      die "$Error: More than one \"\\CheckSum\" command found!\n";
}

## cleaning
sub clean {
  if (-d $tempdir) {
    unlink glob("$tempdir/*");
    rmdir $tempdir;
  }
}

clean();

print "*** Ready.\n";

__END__
