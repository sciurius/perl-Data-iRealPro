# syntax=docker/dockerfile:1
FROM debian:stable-slim AS base

# Environment
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=C.UTF-8 \
    LANGUAGE=en_US.UTF-8

# Install perl and runtime packages.
RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y \
	  build-essential \
          perl \
          cpanminus

# Install perl modules and clean up.
RUN apt-get install --no-install-recommends -y \
    libxml-perl \
    libfont-ttf-perl \
    libpdf-api2-perl \
    libtext-csv-xs-perl \
    libxml-libxml-perl \
    libimager-perl \
    libtemplate-tiny-perl \
    libhttp-server-simple-perl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Perl modules from CPAN.
RUN cpanm \
    Data::Struct \
    HTTP::Server::Simple::CGI \
    File::LoadLines \
    App::Packager

FROM base AS irpweb-prod
RUN cpanm Data::iRealPro

COPY npp.tar.gz .
RUN eval "`perl -V:sitelib`"; \
    tar xvf npp.tar.gz -C $sitelib/Data/iRealPro/res

COPY server.pl irealpro.cgi irealpro-icon.png .

# Default listen to all, port 5000.
EXPOSE 5000
ENTRYPOINT [ "perl", "server.pl" ]
