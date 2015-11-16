NUODB_HOME="/opt/nuodb"

# Start the TE Process and get the PID
sudo ${NUODB_HOME}/bin/nuodbmgr --user domain --password bird --broker localhost --command "start process te host localhost database blergDB options '--dba-user dba --dba-password dba'"
echo
# Finally, show domain summary
sudo ${NUODB_HOME}/bin/nuodbmgr --user domain --password bird --broker localhost --command "show domain summary"
echo
