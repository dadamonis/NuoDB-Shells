#!/bin/bash

if [ $# -eq 0 ];
then
    echo -e "Usage: startsm [<database name>]\n\Where database name is the name of the NuoDB database to create or connect to and Archive Dir is the path and dir of the archive directory."
fi

NUODB_HOME="/opt/nuodb"
NUODB_DATABASE=$1
#NUODB_ARCHIVE=$2

if [ ! -f "/tmp/${NUODB_DATABASE}/1.atm" ];
then
    T=1
    sudo ${NUODB_HOME}/bin/nuodbmgr --user domain --password bird --broker localhost --command "start process sm archive /tmp/${NUODB_DATABASE} host localhost database ${NUODB_DATABASE} initialize yes options '--verbose info,warn,net,error --log /opt/nuodb/logs/sm.log --journal-dir /tmp/${NUODB_DATABASE}Journal' "
    echo "SM Start Code: "$T
else
    T=2
    sudo ${NUODB_HOME}/bin/nuodbmgr --user domain --password bird --broker localhost --command "start process sm archive /tmp/${NUODB_DATABASE} host localhost database ${NUODB_DATABASE} initialize no options '--verbose info,warn,net,error --log /opt/nuodb/logs/sm.log --journal-dir /tmp/${NUODB_DATABASE}Journal' "
    echo "SM Start Code: "$T
fi
#echo "T = "$T
if [ $T -ne 0 ];
then
    sudo ${NUODB_HOME}/bin/nuodbmgr --user domain --password bird --broker localhost --command "start process te host localhost database ${NUODB_DATABASE} options '--dba-user dba --dba-password dba'"
    echo "TE Start Code: "$T
else
    echo "TE Failed with code: "$T
fi
