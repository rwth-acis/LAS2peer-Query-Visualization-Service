#!/usr/bin/env bash

set -e

# print all comands to console if DEBUG is set
if [[ ! -z "${DEBUG}" ]]; then
    set -x
fi

# set some helpful variables
export SERVICE_PROPERTY_FILE='etc/i5.las2peer.services.mobsos.queryVisualization.QueryVisualizationService.properties'
export WEB_CONNECTOR_PROPERTY_FILE='etc/i5.las2peer.connectors.webConnector.WebConnector.properties'
export SERVICE_VERSION=$(awk -F "=" '/service.version/ {print $2}' etc/ant_configuration/service.properties)
export SERVICE_NAME=$(awk -F "=" '/service.name/ {print $2}' etc/ant_configuration/service.properties)
export SERVICE_CLASS=$(awk -F "=" '/service.class/ {print $2}' etc/ant_configuration/service.properties)
export SERVICE=${SERVICE_NAME}.${SERVICE_CLASS}@${SERVICE_VERSION}
export CREATE_DB_SQL='db.sql'
export CREATE_EXAMPLE_DB_SQL='mysqlsampledatabase.sql'
export MYSQL_DATABASE='QVS'
export MYSQL_EXAMPLE_DATABASE='QVS'
export EXAMPLE_DB_TYPE='MySQL'

# check mandatory variables
[[ -z "${MYSQL_USER}" ]] && \
    echo "Mandatory variable MYSQL_USER is not set. Add -e MYSQL_USER=myuser to your arguments." && exit 1
[[ -z "${MYSQL_PASSWORD}" ]] && \
    echo "Mandatory variable MYSQL_PASSWORD is not set. Add -e MYSQL_PASSWORD=mypasswd to your arguments." && exit 1

# set defaults for optional service parameters
[[ -z "${SERVICE_PASSPHRASE}" ]] && export SERVICE_PASSPHRASE='qvPass'
[[ -z "${MYSQL_HOST}" ]] && export MYSQL_HOST='mysql'
[[ -z "${MYSQL_PORT}" ]] && export MYSQL_PORT='3306'
[[ -z "${MYSQL_EXAMPLE_USER}" ]] && export MYSQL_EXAMPLE_USER='example'
[[ -z "${MYSQL_EXAMPLE_PASSWORD}" ]] && export MYSQL_EXAMPLE_PASSWORD='example'
[[ -z "${MYSQL_EXAMPLE_HOST}" ]] && export MYSQL_EXAMPLE_HOST='mysql'
[[ -z "${MYSQL_EXAMPLE_PORT}" ]] && export MYSQL_EXAMPLE_PORT='3306'


# set defaults for optional web connector parameters
[[ -z "${START_HTTP}" ]] && export START_HTTP='TRUE'
[[ -z "${START_HTTPS}" ]] && export START_HTTPS='FALSE'
[[ -z "${SSL_KEYSTORE}" ]] && export SSL_KEYSTORE=''
[[ -z "${SSL_KEY_PASSWORD}" ]] && export SSL_KEY_PASSWORD=''
[[ -z "${CROSS_ORIGIN_RESOURCE_DOMAIN}" ]] && export CROSS_ORIGIN_RESOURCE_DOMAIN='*'
[[ -z "${CROSS_ORIGIN_RESOURCE_MAX_AGE}" ]] && export CROSS_ORIGIN_RESOURCE_MAX_AGE='60'
[[ -z "${ENABLE_CROSS_ORIGIN_RESOURCE_SHARING}" ]] && export ENABLE_CROSS_ORIGIN_RESOURCE_SHARING='TRUE'
[[ -z "${OIDC_PROVIDERS}" ]] && export OIDC_PROVIDERS='https://api.learning-layers.eu/o/oauth2,https://accounts.google.com'

# configure service properties

function set_in_service_config {
    sed -i "s?${1}[[:blank:]]*=.*?${1}=${2}?g" ${SERVICE_PROPERTY_FILE}
}
set_in_service_config stDbHost ${MYSQL_HOST}
set_in_service_config stDbPort ${MYSQL_PORT}
set_in_service_config stDbDatabase ${MYSQL_DATABASE}
set_in_service_config stDbUser ${MYSQL_USER}
set_in_service_config stDbPassword ${MYSQL_PASSWORD}
set_in_service_config exHost ${MYSQL_EXAMPLE_HOST}
set_in_service_config exPort ${MYSQL_EXAMPLE_PORT}
set_in_service_config exDatabase ${MYSQL_EXAMPLE_DATABASE}
set_in_service_config exUser ${MYSQL_EXAMPLE_USER}
set_in_service_config exPassword ${MYSQL_EXAMPLE_PASSWORD}
set_in_service_config exType ${EXAMPLE_DB_TYPE}

# configure web connector properties

function set_in_web_config {
    sed -i "s?${1}[[:blank:]]*=.*?${1}=${2}?g" ${WEB_CONNECTOR_PROPERTY_FILE}
}
set_in_web_config httpPort ${HTTP_PORT}
set_in_web_config httpsPort ${HTTPS_PORT}
set_in_web_config startHttp ${START_HTTP}
set_in_web_config startHttps ${START_HTTPS}
set_in_web_config sslKeystore ${SSL_KEYSTORE}
set_in_web_config sslKeyPassword ${SSL_KEY_PASSWORD}
set_in_web_config crossOriginResourceDomain ${CROSS_ORIGIN_RESOURCE_DOMAIN}
set_in_web_config crossOriginResourceMaxAge ${CROSS_ORIGIN_RESOURCE_MAX_AGE}
set_in_web_config enableCrossOriginResourceSharing ${ENABLE_CROSS_ORIGIN_RESOURCE_SHARING}
set_in_web_config oidcProviders ${OIDC_PROVIDERS}

# ensure the database is ready
while ! mysqladmin ping -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USER} -p${MYSQL_PASSWORD} --silent; do
    echo "Waiting for mysql at ${MYSQL_HOST}:${MYSQL_PORT}..."
    sleep 1
done
echo "${MYSQL_HOST}:${MYSQL_PORT} is available. Continuing..."

# Create the database on first run
if ! mysql -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e "desc ${MYSQL_DATABASE}.questionnaire" > /dev/null 2>&1; then
    echo "Creating database schema..."
    mysql -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE} < ${CREATE_DB_SQL}
fi

if [[ ! -z "${INIT_EXAMPLE_DATABASE}" ]]; then
    # ensure the example database is ready
    while ! mysqladmin ping -h${MYSQL_EXAMPLE_HOST} -P${MYSQL_EXAMPLE_PORT} -u${MYSQL_EXAMPLE_USER} -p${MYSQL_EXAMPLE_PASSWORD} --silent; do
        echo "Waiting for mysql at ${MYSQL_EXAMPLE_HOST}:${MYSQL_EXAMPLE_PORT}..."
        sleep 1
    done
    echo "${MYSQL_EXAMPLE_HOST}:${MYSQL_EXAMPLE_PORT} is available. Continuing..."

    # Create the example database on first run
    if ! mysql -h${MYSQL_EXAMPLE_HOST} -P${MYSQL_EXAMPLE_PORT} -u${MYSQL_EXAMPLE_USER} -p${MYSQL_EXAMPLE_PASSWORD} -e "desc ${MYSQL_EXAMPLE_DATABASE}.customers" > /dev/null 2>&1; then
        echo "Creating example database schema..."
        mysql -h${MYSQL_EXAMPLE_HOST} -P${MYSQL_EXAMPLE_PORT} -u${MYSQL_EXAMPLE_USER} -p${MYSQL_EXAMPLE_PASSWORD} ${MYSQL_EXAMPLE_DATABASE} < ${CREATE_EXAMPLE_DB_SQL}
    fi
fi

# wait for any bootstrap host to be available
if [[ ! -z "${BOOTSTRAP}" ]]; then
    echo "Waiting for any bootstrap host to become available..."
    for host_port in ${BOOTSTRAP//,/ }; do
        arr_host_port=(${host_port//:/ })
        host=${arr_host_port[0]}
        port=${arr_host_port[1]}
        if { </dev/tcp/${host}/${port}; } 2>/dev/null; then
            echo "${host_port} is available. Continuing..."
            break
        fi
    done
fi

# prevent glob expansion in lib/*
set -f
LAUNCH_COMMAND='java -cp lib/* i5.las2peer.tools.L2pNodeLauncher -s service -p '"${LAS2PEER_PORT} ${SERVICE_EXTRA_ARGS}"
if [[ ! -z "${BOOTSTRAP}" ]]; then
    LAUNCH_COMMAND="${LAUNCH_COMMAND} -b ${BOOTSTRAP}"
fi

# start the service within a las2peer node
if [[ -z "${@}" ]]
then
  exec ${LAUNCH_COMMAND} startService\("'""${SERVICE}""'", "'""${SERVICE_PASSPHRASE}""'"\) startWebConnector
else
  exec ${LAUNCH_COMMAND} ${@}
fi
