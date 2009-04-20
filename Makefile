# input file
#RAW := small.tsv.gz
#RAW := ${TMT_ROOT}/share/generated_data/czech_language_model/joint_table.tsv.gz
RAW := ${TMT_ROOT}/share/data/models/language/cs/counts_raw.tsv.gz

# There must be enough space in temp dir!
#TEMP_DIR:=/tmp
TEMP_DIR := .

# How much RAM can we use (for sort)
MEMORY := 85%

SHARE_DIR := ${TMT_ROOT}/share/data/models/language/cs/

COPY_TO_SHARE := lemma_id.pls.gz c_*.pls.gz

# Nasty Makefile hack
# What is the right way to write perl oneliners in makefiles?
1:=$$1
L:=$$L
F:=$$F
P:=$$P
c:=$$c
_:=$$_
/:=$$/

.PHONY: help clean copy_to_share

help:
	less README

counts_unfiltered.tsv.gz: $(RAW)
	zcat $(RAW) |\
	  perl -nle 'my($Ld,$Lg,$Fd,$Pd,$Pg)=split /\t/, $_; print join "\t", lc $Lg,$Pg,lc $Ld,$Pd,$Fd;' |\
	  sort -S $(MEMORY) -T $(TEMP_DIR) | uniq -c | perl -pe 's/^ *([0-9]+) /$1\t/' | gzip > counts_unfiltered.tsv.gz

#counts_sorted_unfiltered.tsv.gz: counts_unfiltered.tsv.gz:
#		zcat unfiltered_counts.tsv.gz | sort -S $(MEMORY) -T $(TEMP_DIR) --key 2,3 --key 1,1rn | gzip > counts_sorted_unfiltered.tsv.gz

counts_filtered.tsv.gz: counts_unfiltered.tsv.gz
	zcat counts_unfiltered.tsv.gz |\
	  perl -nle 'my($count,$Lg,$Pg,$Ld,$Pd,$Fd)=split /\t/, $_; print if $count>1 && $Lg !~ /^[0-9]+$/ && $Ld !~ /^[0-9]+$/ && $Pg !~ /[ZJ]/ && $Pd !~ /[ZJ]/;' |\
	  gzip > counts_filtered.tsv.gz

lemma_id.pls.gz: counts_filtered.tsv.gz create_ids.pl
	zcat counts_filtered.tsv.gz | ./create_ids.pl | gzip > lemma_id.pls.gz


models: lemma_id.pls.gz counts_filtered.tsv.gz create_models.pl
	zcat counts_filtered.tsv.gz | ./create_models.pl

copy_to_share: $(COPY_TO_SHARE)
	cp -t $(SHARE_DIR) $(COPY_TO_SHARE)

clean:
	rm -f counts_*filtered.tsv.gz lemma_id.pls.gz c_*.pls.gz

# Copyright 2009 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.