#!/bin/bash
#find all occurences of TMT in files
find $1 -name "*.pm" -exec grep --color -Hn TMT "{}" \;
