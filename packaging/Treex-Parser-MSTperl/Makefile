SHELL=bash

include ../common.mk

ALLDIRS=${PARSER}

VERSION=`svn info .| grep Revision | perl -ne 's/(\d+)//;printf("0.%05d%s", $$1, "${VERSION_SUFFIX}")'`

MODULES := ${MST}/ \
        $(addprefix ${PARSER}/, MSTperl.pm)
           #$(addprefix ${WRITE}/, Text.pm Treex.pm Sentences.pm Redirectable.pm)

