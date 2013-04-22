#!/bin/bash

. /net/projects/SGE/user/sge_profile > /dev/null

qrsh -cwd -V -p -50 -l mf=5g -now no 'renice 10 $$ > /dev/null; TuneSVM.map.pl $@'

