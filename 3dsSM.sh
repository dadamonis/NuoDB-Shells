# testrestart

NUODB_HOME="/opt/nuodb"
NUODB_DATABASE="blergDB"
NUODB_ARCHIVE="/tmp/archive"

echo
if [ ! -f "${NUODB_ARCHIVE}/1.atm" ];

then
	echo "No existing archive found...initializing a new archive."
    sudo ${NUODB_HOME}/bin/nuodbmgr --user domain --password bird --broker localhost --command "start process sm archive ${NUODB_ARCHIVE} host localhost database ${NUODB_DATABASE} initialize true"

else
	echo "Existing archive found...restarting the database using existing data."
	sudo ${NUODB_HOME}/bin/nuodbmgr --user domain --password bird --broker localhost --command "start process sm archive ${NUODB_ARCHIVE} host localhost database ${NUODB_DATABASE} initialize false "
echo
fi
