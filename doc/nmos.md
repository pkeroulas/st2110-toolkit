# AMWA NMOS

[NMOS](https://amwa-tv.github.io/nmos/) addresses the management of ST2110-based infrastructure regarding:

* device discovery/registration
* device self description of capabilities
* connections between senders and receiver

In order to experiment with this standard, the proposed resources rely
on docker containerization which allows to easily deploy virtual NMOS
nodes and registry.

## Setup the Docker image

You can either build the node Docker image from top folder:

```sh
docker build -t nmos-cpp:v0 -f nmos/Dockerfile .
```

Or you can fetch from Docker registry:

```sh
docker build pk1984/nmos-cpp:v0
```

## Execution

Start, for instance, a registry from a config stored on the host:

```sh
id=$(docker run -d -v /local/path/to/nmos/reg.conf:/tmp/reg.conf -ti nmos-cpp:v0 nmos-cpp-registry /tmp/reg.conf)
```

And monitor:

```sh
docker attach $id
# Ctrl+p, Ctrl-q to exit the container
```
