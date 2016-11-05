#! /bin/make -f

CVT  := perl ../script/irealcvt.pl 
CONV := convert -density 100x100

default : dirs generate compare

export IRP_REGTEST=1

generate : basic selections

basic :
	${CVT} Test_Page.html -o out/Test_Page.html
	${CVT} Test_Page.html -o out/Test_Page.txt
	${CVT} ref/Test_Page.txt -o out/Test_Page.txt.html
	${CVT} Test_Page.html ref/Test_Page.html --playlist "Test Pages" -o out/Test_Pages.html
	${CVT} Test_Page.html -o out/.Test_Page.pdf
	${CONV} out/.Test_Page.pdf out/Test_Page.pdf.ppm 
	${CVT} ref/Test_Pages.html -o out/.Test_Pages.pdf
	${CONV}  out/.Test_Pages.pdf out/Test_Pages.pdf.%d.ppm 
	mv out/.Test_Pages.csv out/Test_Pages.csv 
	${CVT} Test_Page.html -o out/Test_Page.png
	if test -d ../res/prefab; then \
	    ${CVT} Test_Page.html --npp=hand_strict -o out/Test_Page1.jpg; \
	    ${CVT} Test_Page.html --npp=standard -o out/Test_Page2.jpg; \
	else \
	    echo "No NPP testing"; \
	    rm -f ref/Test_Page?.jpg; \
	fi

selections :
	${CVT} ref/Test_Pages.html Song1.html ref/Test_Pages.html --list -o out/sel1.lst
	${CVT} ref/Test_Pages.html Song1.html ref/Test_Pages.html --select=0 --list -o out/sel2.lst
	${CVT} ref/Test_Pages.html Song1.html ref/Test_Pages.html --select=3 -o out/sel3.html

compare :
	@touch out/.ok
	@for i in ref/*; do \
	    if ! cmp -s $$i out/`basename $$i` >/dev/null 2>&1; then \
		echo "FAIL: $$i"; \
		rm -f out/.ok; \
	    else \
		echo "OK: $$i"; \
	    fi; \
	done
	@test -f out/.ok && echo "All tests succeeded"

dirs :
	@rm -fr out; mkdir out
	@test -s Test_Page.html || unzip Test_Pages.zip
