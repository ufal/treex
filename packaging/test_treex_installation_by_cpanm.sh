#!/bin/bash

# tested in SU2

export BASE=myperl
export COMMONLIB=$BASE/basic
export TREEXLIB=$BASE/treex

export PERL5LIB=$TREEXLIB/lib:$COMMONLIB/lib:$PERL5LIB
export PATH=$TREEXLIB/bin:$COMMONLIB/bin:$PATH

mkdir -p $COMMONLIB
mkdir -p $TREEXLIB

curl -LO http://xrl.us/cpanm
perl ./cpanm -l $COMMONLIB Moose

perl ./cpanm -l $TREEXLIB treex-core-testy/Treex-Core-0.08040.tar.gz