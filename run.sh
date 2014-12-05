#!/bin/bash

if [ -z "$VOLT_ACTION" ]; then
    VOLT_ACTION="create"
fi
if [ $VOLT_ACTION == "create" ]; then
    CATALOG="catalog.jar"
fi

function start() {
    : ${PREFIX?"Need to set PREFIX"}
    : ${VOLTPATH?"Need to set VOLTPATH"}
    : ${HOSTCOUNT?"Need to set HOSTCOUNT"}

    stop $PREFIX

    echo "Starting VoltDB servers"
    NAME="${PREFIX}1" LINKS="" startone
    for i in `seq 2 $HOSTCOUNT`; do
        NAME="$PREFIX$i" LEADER_NAME="${PREFIX}1" LINKS="${PREFIX}1" startone
    done

    echo
    echo "Ctrl-c to terminate log tailing"
    docker logs -f ${PREFIX}1
}

function startone() {
    : ${NAME?"Need to set NAME"}
    : ${VOLTPATH?"Need to set VOLTPATH"}

    VOLTPATH=`readlink -f $VOLTPATH`

    stop $NAME

    if [ -z "$LEADER_NAME" ]; then
        LEADER_NAME=$NAME
    fi

    LINK_ARG=""
    IFS=' ' read -a links <<< "$LINKS"
    for l in "${links[@]}"
    do
        LINK_ARG="$LINK_ARG --link $l:$l"
    done

    docker run -d -P -h $NAME $LINK_ARG $DOCKER_ENV -e VOLTDB_LEADER="$LEADER_NAME" -v $VOLTPATH:/opt/voltdb --name $NAME nshi/voltdb-cluster \
        voltdb $VOLT_ACTION -H '$VOLTDB_LEADER' -l voltdb/license.xml -d deployment.xml $VOLT_ARGS $CATALOG

    echo
    echo "IP of $NAME:" `docker inspect --format='{{.NetworkSettings.IPAddress}}' $(docker ps -a | grep -e "\s$NAME" | awk '{ print $1 }')`
    echo "Ports:" `docker port "$NAME" 21212` "(client)" `docker port "$NAME" 8080` "(HTTP)"
    echo
}

function stop() {
    docker rm -f $(docker ps -a | grep -e "\s$1" | awk '{ print $1 }') >/dev/null 2>&1
}

function getleaderip() {
    docker inspect --format='{{.NetworkSettings.IPAddress}}' $(docker ps -a | grep -e "\s$1" | awk '{ print $1 }')
}

function help() {
    echo "Usage: ./run.sh {start prefix hostcount voltdb|stop prefix}"
}

if [ $# -lt 1 ]; then help; exit; else $1 $2; fi
