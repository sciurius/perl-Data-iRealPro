#! /bin/make -f

DOCKER := docker
BUILDARGS := 

VERSION := ${shell perl -Mlib=../../lib -MData::iRealPro -E'say $$Data::iRealPro::VERSION'}
KIT     := https://github.com/sciurius/perl-Data-iRealPro/archive/refs/tags/R${VERSION}.tar.gz

default :: Dockerfile.tmp npp
	${DOCKER} build ${BUILDARGS} --file Dockerfile.tmp \
	    --tag irpweb/irpweb:v${VERSION} \
	    --tag irpweb/irpweb:latest .

Dockerfile.tmp : Dockerfile
	perl -pe 's;RUN cpanm Data::iRealPro;RUN cpanm ${KIT};' \
	    $< > $@

clean ::
	rm -f Dockerfile.tmp npp.tar.gz *~

npp ::
	tar zcf npp.tar.gz -C ../../lib/Data/iRealPro/res \
	    drawable-nodpi-v4 fonts prefab

# publish:
#
# docker tag irpweb/irpweb:latest irpweb/irpweb:v1.16
# docker push irpweb/irpweb:v1.16
# docker push irpweb/irpweb:latest

