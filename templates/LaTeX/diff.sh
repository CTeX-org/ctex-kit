#!/bin/sh

iconv -f GBK -t UTF-8 gbk.tex | diff -u utf8.tex -

