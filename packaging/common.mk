# Old repo
#SVN_BASE=https://svn.ms.mff.cuni.cz/svn/tectomt_devel/trunk
#SVN_TREEX_BASE=$(SVN_BASE)/treex

# Treex is now on GitHub (but we still use svn to pull the modules)
SVN_TREEX_BASE=https://github.com/ufal/treex.git/trunk

ifdef TESTING
    VERSION_SUFFIX=_1
else
    VERSION_SUFFIX=
endif
#VERSION=`svn info .| grep Revision | perl -ne 's/(\d+)//;printf("0.%05d%s", $$1, "${VERSION_SUFFIX}")'`
VERSION=0.00001
DATE=`date +%F`

LIB=lib
TREEX=${LIB}/Treex
CORE=${TREEX}/Core
BIN=bin
MANUAL=${TREEX}/Manual
TUTORIAL=${TREEX}/Tutorial
BLOCK=${TREEX}/Block
UTIL=${BLOCK}/Util
READ=${BLOCK}/Read
READ_T=${READ}/t
WRITE=${BLOCK}/Write
WRITE_T=${WRITE}/t

W2A=${TREEX}/Block/W2A
W2A_T=${W2A}/t
EN=${W2A}/EN
EN_T=${EN}/t
CS=${W2A}/CS
CS_T=${CS}/t
JA=${W2A}/JA
JA_T=${JA}/t
READERS=${TREEX}/Block/Read
READERS_T=${READERS}/t
WRITERS=${TREEX}/Block/Write
#WRITERS_T
TOOLS=${TREEX}/Tool
TAGGER=${TOOLS}/Tagger
TAGGER_T=${TAGGER}/t
SEGMENT=${TOOLS}/Segment
SEGMENT_T=${SEGMENT}/t
SEGMENT_EN=${TOOLS}/Segment/EN
ENGLISHMORPHO=${TOOLS}/EnglishMorpho
FEATURAMA=${TOOLS}/Tagger/Featurama
FEATURAMA_T=${FEATURAMA}/t
PARSER=${TOOL}/Parser
PARSER_T=${PARSER}/t
MST=${PARSER}/MSTperl
LEXICON=$(TOOLS)/Lexicon

PREFIX=${TREEX}

SVN=0

.PHONY: clean rebuild refresh

default: build

all: clean build test

# Using "make SVN=0" you can just copy the modules from your local repository (instead of "exporting" from git),
# so you can check dzil test before commiting.
# note: 'svn export' still works only because the git repo is on GitHub
# TODO: rather then svn export, use git status in case of SVN=1 and require commit of modified files (or something like that)
export.tmp:
	mkdir -p ${ALLDIRS}
	for module in $(MODULES) ; do\
		echo $$module; \
          [[ $(SVN) == 1 ]] && svn export $(SVN_TREEX_BASE)/$$module $$module || \
                               cp -r ../../$$module $$module; \
	done
	rm -rf lib/Treex/Core/Parallel # we don't want to release blocks for parallel runs
	rm -f lib/Treex/Core/Service.pm lib/Treex/Core/t/service.t # not ready for distribution
	rm -f lib/Treex/Core/CacheBlock.pm lib/Treex/Core/Cloud.pm lib/Treex/Core/Coordinations.pm lib/Treex/Core/Loader.pm
	rm -f lib/Treex/Block/Read/ConsumerReader.pm lib/Treex/Block/Read/ProducerReader.pm # client-server blocks
	rm -f lib/Treex/Block/Util/PMLTQ.pm	# dependent on Tred::Config (do we need them in the distro?)
	rm -f lib/Treex/Block/Util/PMLTQMark.pm # dependent on Tred::Config (do we need them in the distro?)
	rm -f lib/Treex/Block/Util/FixPMLStructure.pm
	if [ -d lib/Treex/Core/share ]; then \
		mv -f lib/Treex/Core/share .; \
		find share -name '.svn' -exec rm -rf {} \; ;\
		find share -name '.git' -exec rm -rf {} \; ;\
	fi; \
	touch $@

testcollect.tmp: export.tmp
	mkdir -p t
	#find . ! -path './.*' ! -path './t/*' ! -path '*/.git*' ! -path '*/obsolete*' -regex '.*\/x?t\/[^/]*' | xargs -IFILE mv FILE t #find all tests and move them to t/ directory
	find . ! -path './.*' ! -path './t/*' ! -path '*/.git*' -regex '.*\/x?t\/[^/]*' | xargs -IFILE mv FILE t #find all tests and move them to t/ directory
	find . ! -path './.*' ! -regex '\.\/t\(\/.*\)?' -regex '.*\/t\(\/.*\)?' -delete  #delete t/ directories from original location
	touch $@

dist.ini: 
	cat dist.ini.template | perl -ne "s/version =.+/version = $(VERSION)/;print" > $@

Changes: Changes.template dist.ini
	perl -pe "s/^VERSION/$(VERSION)/;s/DATE$$/$(DATE)/" < $< > $@

clean:
	rm -rf lib bin Treex-* .build *.tmp dist.ini test-* perlcritic.rc Changes; \
	#if [ `svn info t 2>/dev/null | wc -l` == 0 ]; then rm -rf t; fi; \
	#if [ `svn info share 2>/dev/null | wc -l` == 0 ]; then rm -rf share; fi; \

parser.tmp:
postprocess: export.tmp

perlcritic.rc:
	cp ../$@ .
prebuild: testcollect.tmp dist.ini postprocess parser.tmp perlcritic.rc Changes
build.tmp: prebuild
	dzil build
	touch $@
build: build.tmp
rebuild: clean build
refresh: clean prebuild

test: prebuild
	((dzil test 2>&1 1>&3 | tee test-test.err) 3>&1 1>&2 | tee test-test.out) 2>&1 | tee test-test.mix
quicktest: prebuild
	((dzil test --no-author 2>&1 1>&3 | tee test-quick.err) 3>&1 1>&2 | tee test-quick.out) 2>&1 | tee test-quick.mix
fulltest: prebuild
	((dzil test --release 2>&1 1>&3 | tee test-full.err) 3>&1 1>&2 | tee test-full.out) 2>&1 | tee test-full.mix
retest: clean test
