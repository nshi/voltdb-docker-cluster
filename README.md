VoltDB Docker Image
===============

This docker image is built to run VoltDB. It doesn't have VoltDB bundled, you
have to specify a VoltDB package on the host to use when you start the
containers using this image.

The VoltDB package specified by the VOLTPATH environment variable should be
owned by the current user(not root).

The helper `run.sh` script can start a VoltDB cluster of the specified size on
the local machine. You can kill and rejoin VoltDB nodes as you like.

To build the image, use the following command
```bash
docker build --force-rm=true -t voltdb-image .
```

Before starting cluster(s), create a docker bridge network for containers to attach to so that they can access each other
```bash
docker network create <name of docker bridge network>
```

To start a cluster, use the following command
```bash
PREFIX="boston" HOSTCOUNT="2" SITES_PER_HOST="2" NETWORK=<name of docker bridge network> VOLTPATH=<path of VOLTDB package> ./run.sh start
```

To start a replica cluster, just add a parameter to the command above
```bash
REPLICA="true"
```

To issue commands to a particular host when it is running, use the following command
```bash
docker exec -i -t -u <current user> <container name of the host> bash
```
**Note**: The container names of all running hosts can be inspected using `docker ps`, they all
consist of the prefix and a number, for example, `boston1`.
