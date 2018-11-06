#! /bin/make -f

PROJECT := Data-iRealPro
TMP_DST = ${HOME}/tmp/${PROJECT}

to_tmp :
	rsync -avH --files-from=../MANIFEST ../ ${TMP_DST}/

to_tmp_cpan :
	rsync -rptgov --files-from=MANIFEST.CPAN ../ ${TMP_DST}/

