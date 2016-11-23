#!/usr/bin/env perl

# Copyright (C) 2012--2016 by Leo Liu <leoliu.pku@gmail.com>
#
# Run this script to add tfm font map for zhmCJK package.

chomp ( my $texmfdist = `kpsewhich -var-value=TEXMFDIST` ) ;
my $texfontsmap = "$texmfdist/fonts/map/fontname/texfonts.map";

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
