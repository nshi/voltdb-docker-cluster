#!/bin/bash
if [ -z "$VOLT_ACTION" ]; then
VOLT_ACTION="create"
fi
function start() {
: ${PREFIX?"Need to set PREFIX"}
: ${VOLTPATH?"Need to set VOLTPATH"}
: ${HOSTCOUNT?"Need to set HOSTCOUNT"}
# Build deployment files (deployment.xml and producer_dr_[en/dis]able.xml
if ([ -z "$DEPLOY" ] && ([ "$CLUSTER_ID" ] || [ "$K_FACTOR" ] || [ "$SITES_PER_HOST" ] || [ "$DR_LISTEN" ])); then
  if [ -z "$SITES_PER_HOST" ]; then SITES_PER_HOST="2"; fi
  if [ -z "$K_FACTOR" ]; then K_FACTOR="0"; fi
  if [ -z "$DR_LISTEN" ]; then DR_LISTEN="false"; fi
  if [ -z "$DR_PRODUCER_HOST" ]; then
    if [ -z "$CLUSTER_ID" ]; then CLUSTER_ID="1"; fi
    DR_SOURCE=""
  else
    if [ -z "$CLUSTER_ID" ]; then CLUSTER_ID="2"; fi
    DR_SOURCE='<connection source="'$DR_PRODUCER_HOST'"/>'; DR_LISTEN="false"
  fi
  if ( HOSTCOUNT=="2" ); then DISABLEPD='<partition-detection enabled="false"/>'; else DISABLEPD=''; fi
  if ([ -z "$CATALOG" ]); then SCHEMA="ddl"; else SCHEMA="catalog"; fi
  echo '<deployment><cluster hostcount="'$HOSTCOUNT'" sitesperhost="'$SITES_PER_HOST'" kfactor="'$K_FACTOR'" schema="'$SCHEMA'"/>'$DISABLEPD'<httpd enabled="true"><jsonapi enabled="true"/></httpd><dr id="'$CLUSTER_ID'" listen="'$DR_LISTEN'">'$DR_SOURCE'</dr></deployment>' > $VOLTPATH/DOCKER/$PREFIX/deployment.xml
  if [ DR_LISTEN=='false' ]; then
    DR_LISTEN="true"
    echo '<deployment><cluster hostcount="'$HOSTCOUNT'" sitesperhost="'$SITES_PER_HOST'" kfactor="'$K_FACTOR'" schema="'$SCHEMA'"/>'$DISABLEPD'<httpd enabled="true"><jsonapi enabled="true"/></httpd><dr id="'$CLUSTER_ID'" listen="'$DR_LISTEN'">'$DR_SOURCE'</dr></deployment>' > $VOLTPATH/DOCKER/$PREFIX/producer_dr_enable.xml
  else
    DR_LISTEN="false"
    echo '<deployment><cluster hostcount="'$HOSTCOUNT'" sitesperhost="'$SITES_PER_HOST'" kfactor="'$K_FACTOR'" schema="'$SCHEMA'"/>'$DISABLEPD'<httpd enabled="true"><jsonapi enabled="true"/></httpd><dr id="'$CLUSTER_ID'" listen="'$DR_LISTEN'">'$DR_SOURCE'</dr></deployment>' > $VOLTPATH/DOCKER/$PREFIX/producer_dr_disable.xml
  fi
  DEPLOY="${VOLTPATH}/DOCKER/${PREFIX}/deployment.xml"
else
: ${DEPLOY?"Need to set DEPLOY"}
fi
#Include catalog option if specified
if ([ -z "$CATALOG" ]); then
  CATALOG_OPTION=""
else
  CATALOG_OPTION="/opt/voltdb/${VOLTPATH}/DOCKER/${PREFIX}/${CATALOG}"
fi
stop $PREFIX
echo "Starting VoltDB servers"
NAME="${PREFIX}1" LINKS="" startone
for i in `seq 2 $HOSTCOUNT`; do
NAME="$PREFIX$i" LEADER_NAME="${PREFIX}1" LINKS="${PREFIX}1" startone
done
#Todo: figure out when the producer cluster is stable ( public listen ports are opened early by docker :( )
#if [ -z "$DR_PRODUCER" ]; then
#  for j in {0..60..5}
#  do
#    echo "Waiting for Volt to initialize $j"
#    for j in {0..4..1}
#    do
#      nc -z `docker port producer1 21212 | tr ":" " "`; echo $?
#      if [ $? -ne 0 ]; then break 2; fi
#      sleep 1
#    done
#  done
#fi
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
# Create docker volumes for this server
if [ $VOLT_ACTION == "create" ]; then
  sudo rm -r $VOLTPATH/DOCKER/$PREFIX/$NAME/log/
  sudo rm -r $VOLTPATH/DOCKER/$PREFIX/$NAME/voltdbroot/
  sudo mkdir $VOLTPATH/DOCKER/$PREFIX/$NAME/log/
  sudo mkdir $VOLTPATH/DOCKER/$PREFIX/$NAME/voltdbroot/ 
  sudo chmod 777 $VOLTPATH/DOCKER/$PREFIX/$NAME/log/
  sudo chmod 777 $VOLTPATH/DOCKER/$PREFIX/$NAME/voltdbroot/
  # Provide a share directory that all servers have visibility to
  if [ ! -d "$VOLTPATH/DOCKER/SHARE" ]; then
    sudo mkdir $VOLTPATH/DOCKER/SHARE/
    sudo chmod 777 $VOLTPATH/DOCKER/SHARE/
  fi
  # Provide a server local directory that all other servers have visibility to
  if [ ! -d "$VOLTPATH/DOCKER/SHARE/$NAME" ]; then
    sudo mkdir $VOLTPATH/DOCKER/SHARE/$NAME/
    sudo chmod 777 $VOLTPATH/DOCKER/SHARE/$NAME/
  fi
fi
LINK_ARG=""
IFS=' ' read -a links <<< "$LINKS"
for l in "${links[@]}"
do
LINK_ARG="$LINK_ARG --link $l:$l"
done
# Start docker
docker run -d -P -h $NAME $LINK_ARG $DOCKER_ENV -v $VOLTPATH:/opt/voltdb -v $VOLTPATH/DOCKER/$PREFIX/$NAME:/tmp/voltdbroot -v $VOLTPATH/DOCKER/SHARE:/tmp/share -v $VOLTPATH/DOCKER/SHARE/$NAME:/tmp/sharelocal --name $NAME nshi/voltdb-cluster \
sh -c "cd /tmp/voltdbroot;voltdb $VOLT_ACTION $CATALOG_OPTION -H $LEADER_NAME -l /opt/voltdb/voltdb/license.xml -d /opt/voltdb/$DEPLOY $VOLT_ARGS"
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
