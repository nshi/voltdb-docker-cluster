VoltDB Docker Image
===============

This docker image is built to run VoltDB. It doesn't have VoltDB bundled, you
have to specify a VoltDB package on the host to use when you start the
containers using this image.

The helper `run.sh` script can start a VoltDB cluster of the specified size on
the local machine. You can kill and rejoin VoltDB nodes as you like.

To build the image, use the following command
```bash
docker build --force-rm=true -t voltdb-image .
```
