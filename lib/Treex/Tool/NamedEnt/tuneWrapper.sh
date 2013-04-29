#!/bin/bash

. /net/projects/SGE/user/sge_profile > /dev/null
export PATH=$PATH:~pajas/bin

qcmd -j -- "./TuneSVM.map.pl $@"
#qsub -cwd -j y -V "perl TuneSVM.map.pl oneword.feat $@"
#qrsh -cwd -V -p -50 -l mf=5g -now no 'renice 10 $$ > /dev/null; perl TuneSVM.map.pl oneword.feat $@'

