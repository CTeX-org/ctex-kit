#!/usr/bin/env python

import sys, os, re

def update_version(file, date, version):
    f = open(file)
    update_next = False
    line_re = re.compile("^(\s*)\[(\d+/\d+/\d+) ([^\s]+) (.*)$")
    lines = ""

    for line in f:
        if update_next:
            update_next = False
            m = line_re.match(line)
            if m:
                line = "%s[%s %s %s\n" % (m.group(1), date, version, m.group(4))

        elif "ProvidesPackage" in line or "ProvidesClass" in line or "ProvidesFile" in line:
            update_next = True

        lines += line

    f.close()
    f = open(file, "w")
    os.linesep = "\n"
    f.write(lines)
    f.close()

if len(sys.argv) != 3:
    print("%s %s" % (sys.argv[0], "<date> <version>"))
    print("like: %s %s" % (sys.argv[0], "2009/05/20 v0.91"))
    sys.exit(1)

file_list = [ "../ctex.sty", "../ctexcap.sty", "../ctexart.cls", "../ctexbook.cls", "../ctexrep.cls",
    "../back/ctexutf8.sty", "../back/ctexcaputf8.sty", "../back/ctexartutf8.cls",
    "../back/ctexbookutf8.cls", "../back/ctexreputf8.cls",]

for file in file_list:
    update_version(file, sys.argv[1], sys.argv[2])

