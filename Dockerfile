FROM ubuntu:14.04
MAINTAINER Ning Shi <nshi@voltdb.com>

# Public VoltDB ports
EXPOSE 22 5555 8080 8081 9000 21211 21212

# Internal VoltDB ports
EXPOSE 3021 4560 9090

ENV VOLTDB_DIST /opt/voltdb
ENV PATH $PATH:$VOLTDB_DIST/bin

RUN apt-get update
RUN apt-get install -y procps python vim openjdk-7-jdk

WORKDIR $VOLTDB_DIST
