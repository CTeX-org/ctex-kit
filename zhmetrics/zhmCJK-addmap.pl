#!/usr/bin/env perl

chomp ( my $texmfdist = `kpsewhich -var-value=TEXMFDIST` ) ;
$texfontsmap = "$texmfdist/fonts/map/fontname/texfonts.map";

my $absent = 1;

if (-r "$texfontsmap") {
	open (FOO, "<$texfontsmap");
	my @lines = <FOO>;
	chomp(@lines);
	close(FOO);
	for my $line (@lines) {
		if ($line =~ m/^\s*include\s+zhmCJK\.map\s*/) {
			$absent = 0;
		}
	}
}

if ($absent) {
	open (FOO, ">>$texfontsmap") || die("Cannot write $texfontsmap\n");
	print FOO "include zhmCJK.map\n";
	close(FOO);
}
