#!/bin/bash
set -e

os_type=`uname -s`
case $os_type in
    Darwin*)
        ECHO="echo -e"
    ;;
    Linux*)
        ECHO="echo -e"
    ;;
esac

ME=`basename $0`
SCRIPT_DIR=`dirname $0`

: ${SELF_ROOT:=`dirname ${SCRIPT_DIR}`}
pushd ${SELF_ROOT} >/dev/null
SELF_ROOT=`pwd`
popd >/dev/null

# Only set APPLICATION_HOME_DIR if not already set
[ -z "${APPLICATION_HOME_DIR}" ] && APPLICATION_HOME_DIR=`cd "${SELF_ROOT}/../.." >/dev/null; pwd`

: ${NUODB_HOME:="/opt/nuodb"}
: ${BROKER_HOST:="localhost"}
: ${TARGET_HOST:="localhost"}
: ${BROKER_PORT:="48004"}
: ${BROKER_DOMAIN:="domain"}
: ${BROKER_DOMAIN_PASSWORD:="bird"}
: ${DATABASE_DDL:="create-tables.sql"}
: ${DATABASE_NAME:="SubDB_LARGE"}
: ${DATABASE_USER:="dba"}
: ${DATABASE_PASSWORD="dba"}
: ${DATABASE_SCHEMA="DG"}
: ${STORAGE_DIR:="/Database/dash"}
: ${ARCHIVE_DIR:="${STORAGE_DIR}"}
: ${ARCHIVE_URL:="${ARCHIVE_DIR}/${DATABASE_NAME}"}
: ${TMP_LOGS_DIR:="/tmp"}
: ${SQL_SCRIPTS_DIR:="${APPLICATION_HOME_DIR}/sql"}
: ${STATS_LOGS_DIR:="/tmp/stats"}
: ${NUODB_LOGS_DIR:="/var/log/nuodb"}
: ${MANAGE_LOG_FILE:="${TMP_LOGS_DIR}/manage-${DATABASE_NAME}.log"}
: ${ENGINE_ARGS:="--mem 8G --commit local --verbose info,warn,net,error"}
: ${NUODB_MANAGER_JAR:="${NUODB_HOME}/jar/nuodbmanager.jar"}

if [[ -e "${SCRIPT_DIR}/nuodbmanager.jar" ]]
then
    NUODB_MANAGER_JAR=${SCRIPT_DIR}/nuodbmanager.jar
fi

NUODB_MANAGER_RUN="java -jar ${NUODB_MANAGER_JAR} --user ${BROKER_DOMAIN} --password ${BROKER_DOMAIN_PASSWORD} --broker ${BROKER_HOST}:${BROKER_PORT}"
NUODB_MANAGER_RUN_COMMAND="${NUODB_MANAGER_RUN} --command"

NUODB_ENGINE=${NUODB_HOME}/bin/nuodb

if [ ! -d "${STATS_LOGS_DIR}" ]; then
	mkdir -p "${STATS_LOGS_DIR}"
fi

SYS_LOAD_LOG=${STATS_LOGS_DIR}/stat_load.log
CPU_STAT_LOG=${STATS_LOGS_DIR}/stat_cpu.log
DISK_STAT_LOG=${STATS_LOGS_DIR}/stat_disk.log
NET_STAT_LOG=${STATS_LOGS_DIR}/stat_net.log

function startsm()
{
    ${ECHO} "[INFO] Starting archive manager and recreating database" | tee -a ${MANAGE_LOG_FILE}
    SM_ARGS="${ENGINE_ARGS} --log ${NUODB_LOGS_DIR}/sm-${DATABASE_NAME}.log --journal enable"
    if [[ -z ${FORCE_INIT} ]]
    then
        ${ECHO} "[INFO] Restarting storage manager with existing archive" | tee -a ${MANAGE_LOG_FILE}
        ${ECHO} "\tExecute: ${NUODB_MANAGER_RUN_COMMAND} start process sm archive ${ARCHIVE_URL} host ${TARGET_HOST} database ${DATABASE_NAME} initialize no options '${SM_ARGS}'"
        ${NUODB_MANAGER_RUN_COMMAND} "start process sm archive ${ARCHIVE_URL} host ${TARGET_HOST} database ${DATABASE_NAME} initialize no options '${SM_ARGS}'" | tee -a ${MANAGE_LOG_FILE}
        sleep 2
    else
        if [[ -e ${ARCHIVE_URL} ]]
        then
            rm -fr ${ARCHIVE_URL}
        fi
        ${ECHO} "\tExecute: ${NUODB_MANAGER_RUN_COMMAND} start process sm archive ${ARCHIVE_URL} host ${TARGET_HOST} database ${DATABASE_NAME} initialize true options '${SM_ARGS}'"
        ${NUODB_MANAGER_RUN_COMMAND} "start process sm archive ${ARCHIVE_URL} host ${TARGET_HOST} database ${DATABASE_NAME} initialize true options '${SM_ARGS}'" | tee -a ${MANAGE_LOG_FILE}
        sleep 2
    fi
}

function startte()
{
    ${ECHO} "[INFO] Starting transaction engine" | tee -a ${MANAGE_LOG_FILE}
    TE_ARGS="--threads 32 --dba-user ${DATABASE_USER} --dba-password ${DATABASE_PASSWORD} ${ENGINE_ARGS} --log ${NUODB_LOGS_DIR}/te-${DATABASE_NAME}.log"
    ${ECHO} "\tExecute: ${NUODB_MANAGER_RUN_COMMAND} start process te host ${TARGET_HOST} database ${DATABASE_NAME} options '${TE_ARGS}'"
    ${NUODB_MANAGER_RUN_COMMAND} "start process te host ${TARGET_HOST} database ${DATABASE_NAME} options '${TE_ARGS}'" | tee -a ${MANAGE_LOG_FILE}
    sleep 1
}

function startmgr()
{
    ${ECHO} "[INFO] Starting nuodb manager" | tee -a ${MANAGE_LOG_FILE}
    ${ECHO} "\tExecute: ${NUODB_MANAGER_RUN}"
    ${NUODB_MANAGER_RUN} | tee -a ${MANAGE_LOG_FILE}
    sleep 1
}

function startsql()
{
    ${ECHO} "[INFO] Starting SQL client" | tee -a ${MANAGE_LOG_FILE}
    ${NUODB_HOME}/bin/nuosql ${DATABASE_NAME}@${BROKER_HOST}:${BROKER_PORT} --user ${DATABASE_USER} --password ${DATABASE_PASSWORD} --schema ${DATABASE_SCHEMA}
}

function loadddl()
{
    echo "[INFO] Loading db ddl" | tee -a ${MANAGE_LOG_FILE}
    ${NUODB_HOME}/bin/nuosql ${DATABASE_NAME}@${BROKER_HOST}:${BROKER_PORT} --user ${DATABASE_USER} --password ${DATABASE_PASSWORD} --schema ${DATABASE_SCHEMA} --file ${SQL_SCRIPTS_DIR}/${DATABASE_DDL} >> ${MANAGE_LOG_FILE} | tee -a ${MANAGE_LOG_FILE}
}

function shutdown()
{
    killall mpstat iostat sar || true
    ${ECHO} "[INFO] Shutting down database" | tee -a ${MANAGE_LOG_FILE}
    ${ECHO} "\tExecute: ${NUODB_MANAGER_RUN_COMMAND} shutdown database ${DATABASE_NAME}"
    ${NUODB_MANAGER_RUN_COMMAND} "shutdown database ${DATABASE_NAME}" | tee -a ${MANAGE_LOG_FILE}
}

function show()
{
    echo "NuoDB Bootstrap Environment"
    echo ""
    echo "  BROKER_HOST:        ${BROKER_HOST}"
    echo "  TARGET_HOST:        ${TARGET_HOST}"
    echo "  ARCHIVE_URL:        ${ARCHIVE_URL}"
    echo "  DATABASE_NAME:      ${DATABASE_NAME}"
    echo "  STATS_LOGS_DIR:     ${STATS_LOGS_DIR}"
    echo "  NUODB_LOGS_DIR:     ${NUODB_LOGS_DIR}"
    echo ""
    echo "Domain Summary: "
    ${NUODB_MANAGER_RUN} --command "show domain summary" | tee -a ${MANAGE_LOG_FILE}
}

function logstats()
{
    ${ECHO} "[INFO] Gathering system statistics..."  | tee -a ${CPU_STAT_LOG} ${DISK_STAT_LOG} ${NET_STAT_LOG} ${MANAGE_LOG_FILE}

    os_type=`uname -s`
    case $os_type in
        Darwin*)
            iostat -d 10 36000 >> ${DISK_STAT_LOG} 2>&1 &
            sar -u 10 36000 >> ${CPU_STAT_LOG} 2>&1 &
            sar -n DEV 10 36000 >> ${NET_STAT_LOG} 2>&1 &
        ;;
        Linux*)
            iostat -dx 10 36000 >> ${DISK_STAT_LOG} 2>&1 &
            mpstat 10 36000 >> ${CPU_STAT_LOG} 2>&1 &
            sar -n DEV 10 36000 >> ${NET_STAT_LOG} 2>&1 &
        ;;
    esac
}

function help()
{
  cat <<- __EOF__

  EXECUTION

  This script may be run by simply executing the script, passing in the
  corresponding bash function name, or no arguments to display the command
  line syntax.

  ENVIRONMENT VARIABLES

  The following is a list of the environment variables and their purpose:

    BROKER_HOST     is the host having a NuoDB broker running; the default
                    value is 'localhost'

    TARGET_HOST     is the host ip address on which a TE or SM is started;
                    the default value is BROKER_HOST

  STARTING STORAGE MANAGERS

  The first time you start the storage managers, or when you wish to force the
  reinitialization of an archive, ensure the archive directory exists then run
  the following command line:

    FORCE_INIT=1 ${ME} startsm

  Do NOT run the FORCE_INIT option when using archive copies as this will
  cause the copied archive to be truncated.

  Otherwise to start the storage manager you simply run the following command:

    ${ME} startsm

  STARTING TRANSACTION ENGINES

  To start a transaction engine simply run the following command:

    ${ME} startte

  OTHER

  All functions of this script print out the elapsed time to run as the last
  output.

__EOF__
}

if [ $# -eq 0 ]; then
    ${ECHO} "\nSyntax:\n\t${ME} [<command> ...]\n\
\nCommands include:\
\n\t help        displays extended help and explanations\
\n\t startsm     starts the sm's across all nodes targeted\
\n\t startte     starts the te's across all nodes targeted\
\n\t startsql    starts the nuodb command line sql tool in interactive mode\
\n\t startmgr    starts the nuodb command line manager in interactive mode\
\n\t logstats    turns on stats logging on all targeted hosts\
\n\t shutdown    shuts down the entire database across all hosts\
\n\t show        show the environment variables
\n"
fi

while [ $# -gt 0 ]
do
    CMD=$1
    time {
      ${CMD}
      shift
    }
    ${ECHO} ""
done

exit
