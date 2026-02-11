# Podman and Docker

## Build

_Use the Makefile: `make`_

    docker build -t irpweb/irpweb:vx.yy .
    docker tag irpweb/irpweb:vx.yy irpweb/irpweb:latest

## Push to repo

_Use the Makefile: `make publish`_

    docker push irpweb/irpweb:latest
    docker push irpweb/irpweb:vx.yy

## Running irpweb

Podman:

	podman run --rm --publish 5000:5000 docker.io irpweb/irpweb:latest

Docker:

	docker run --rm --publish 5000:5000 irpweb/irpweb:latest

## irpweb script

The `irpweb` script can be used to conveniently start and stop the
server.

## Notes

Use `--publish` to change the server port if necessary.

3 x Control-C will **not** terminate the container. Use `podman stop`
(or `docker stop`). Alternatively, send a terminate request:

    http://localhost:5000/exit

