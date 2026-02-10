# Podman and Docker

## Build

_Use the Makefile_

    docker build -t irpweb/irpweb:v1.16 .
    docker tag irpweb/irpweb:v1.16 irpweb/irpweb:latest

## Push to repo

    docker push irpweb/irpweb:latest
    docker push irpweb/irpweb:v1.16

## Running irpweb

Podman:

	podman run --rm --publish 5000:5000 docker.io irpweb/irpweb:latest

Docker:

	docker run --rm --publish 5000:5000 irpweb/irpweb:latest

## Notes

Use `--publish` to change the server port if necessary.

3 x Control-C will **not** terminate the container. Use `podman stop`
(or `docker stop`). Alternatively, send a terminate request:

    http://localhost:5000/exit

