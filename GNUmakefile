#! /bin/make -f

################ Pass-through ################

.PHONY : all
all :	Makefile cleanup
	mv Makefile.old Makefile
	$(MAKE) -f Makefile all

.PHONY : test
test : Makefile
	env PERL5LIB=$(shell pwd)/CPAN $(MAKE) -f Makefile test

.PHONY : clean
clean : cleanup
	rm -f *~

.PHONY : cleanup
cleanup : Makefile
	$(MAKE) -f Makefile clean

.PHONY : dist
dist : Makefile resources
	$(MAKE) -f Makefile dist

.PHONY : install
install : Makefile
	$(MAKE) -f Makefile install

Makefile : Makefile.PL
	perl Makefile.PL

################ Extensions ################

PERL := perl
PROJECT := irealcvt
TMP_DST := ${HOME}/tmp/${PROJECT}
RSYNC_ARGS := -rptgoDvHL
W10DIR := /Users/Johan/${PROJECT}

to_tmp :
	rsync ${RSYNC_ARGS} --files-from=MANIFEST    ./ ${TMP_DST}/

to_tmp_npp :
	rsync ${RSYNC_ARGS} --files-from=MANIFEST.NPP ./ ${TMP_DST}/

to_tmp_cpan :
	rsync ${RSYNC_ARGS} --files-from=MANIFEST.CPAN ./ ${TMP_DST}/

to_c :
	${MAKE} to_tmp to_tmp_cpan to_tmp_npp TMP_DST=/mnt/c${W10DIR}

