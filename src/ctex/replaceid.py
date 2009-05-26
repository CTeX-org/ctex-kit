#!/usr/bin/env python

import os

for root, dirs, files in os.walk('.'):
    for file in files:
        if os.path.splitext(file)[1] == '.swp':
            continue
        f = open(os.path.join(root, file), "r")
        line = f.readline()
        other = f.read()

        if line and "$Id$" in line:
            newline = line.replace("$Id$", file)

            f.close()
            f = open(os.path.join(root, file), "w")
            f.write(newline)
            f.write(other)
            f.close()

