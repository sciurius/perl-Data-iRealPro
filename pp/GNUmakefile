#! /bin/make -f

PROJECT := Data-iRealPro
TMP_DST = ${HOME}/tmp/${PROJECT}

to_tmp :
	rsync -avH --files-from=../MANIFEST ../ ${TMP_DST}/
	rsync -avH --files-from=MANIFEST.PP ../ ${TMP_DST}/

to_tmp_cpan :
	rsync -avH --files-from=MANIFEST.CPAN ../ ${TMP_DST}/

