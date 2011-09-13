#!/bin/bash
cat dtest.conll | ./make_czech_tags.pl > test.conll
./test_conll.pl test.conll dmodel ../config.txt