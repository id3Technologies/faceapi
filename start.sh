#!/bin/sh

# Load the .env variable in local context
eval "$(echo $(cat .env))"

# Initialize colors
RED='\e[31m'
GREEN='\e[32m'
NC='\e[0m'

primary=1
#auth can have 3 possible values : sso, apikey, both
auth=sso

while [ "$1" != "" ]; do
    case $1 in
        -s | --secondary )      shift
                                primary=0
                                ;;
        -a | --authentication ) shift
                                auth=$1
                                shift
                                ;;
    esac
done



if [ $primary = 0 ]
then
    # For slave instance, we check that the services on the primary instance are available and accessible
    URL_KEYCLOAK=http://$PRIMARY_INSTANCE:8070
    URL_MINIO=http://$PRIMARY_INSTANCE:9000
    HTTP_CODE_KEYCLOAK=$(curl -sIk $URL_KEYCLOAK | grep "HTTP/1.1" | awk {'print $2'})
    HTTP_CODE_MINIO=$(curl -sIk $URL_MINIO | grep "HTTP/1.1" | awk {'print $2'})
    if [ "$HTTP_CODE_KEYCLOAK" != "200" ] || [ "$HTTP_CODE_MINIO" = "" ]
    then
        echo "${RED}Error : cannot start the setup process. The primary instance (master) is not ready or accessible.\n${NC}"
        echo "Please verify that the primary instance is accessible on 8070 and 9000 ports from here.\n"
        echo "To do this verification, you can either use curl, telnet or wget"
        echo "For example, with telnet, the two next commands must responds \"Connected to $PRIMARY_INSTANCE\"\n"
        echo "telnet $PRIMARY_INSTANCE 8070"
        echo "telnet $PRIMARY_INSTANCE 9000\n"
        exit 1
    fi
fi

if [ -x "$(command -v firewall-cmd)" ]
then
    echo "firewalld service is started on this server. Adding a rule to enable NAT. This is needed for the docker containers to communicate properly between them and to access the external world (internet)."
    firewall-cmd --zone=public --add-masquerade --permanent
    echo "${GREEN}Firewalld is now properly configured : OK${NC}\n"
fi

if [ $auth = 'apikey' ]
then
    export AUTHENTICATION_MODE="API_KEY"
else
    # SSO by default
    export AUTHENTICATION_MODE="KEYCLOACK"
fi

if [ $auth = 'both' ]
then
    export UPSTREAM_BACKEND_URL="203.0.113.10:8085"
    export UPSTREAM_AUTH_BACKEND_URL="203.0.113.2:8085"
else
    export UPSTREAM_BACKEND_URL="203.0.113.2:8085"
    export UPSTREAM_AUTH_BACKEND_URL="203.0.113.2:8085"
fi

if [ $primary = 1 ]
then
    echo "Starting docker-compose setup - primary instance\n"
    if [ $auth = 'both' ]
    then
        echo "Authentication mode : both. 2 Face REST Api instance are needed, one for each authentication mode.\n"
        docker-compose -f docker-compose.yml -f docker-compose-multi-auth-mode.yml up -d
    else
        docker-compose -f docker-compose.yml up -d
    fi
else
    echo "Starting docker-compose setup - secondary instance\n"
    if [ $auth = 'both' ]
    then
        echo "Authentication mode : both. 2 Face REST Api instance are needed, one for each authentication mode.\n"
        docker-compose -f docker-compose.secondary.yml -f docker-compose-multi-auth-mode.yml up -d
    else
        docker-compose -f docker-compose.secondary.yml up -d
    fi
fi

echo "${GREEN}Docker-compose setup done. All components are started.${NC}\n"

# Wait for keycloak to be ready before restarting
if [ $primary = 1 ]
then
    COUNTER=0
    DELAY_RETRY=5
    PROCESS_TIMEOUT=150
    TOTAL_TIME=0
    HTTP_CODE_KEYCLOAK=""
    echo "Waiting for Keycloak to be fully configured and started before restarting docker..."
    while [ "$HTTP_CODE_KEYCLOAK" != "200" ] && [ $TOTAL_TIME -le $PROCESS_TIMEOUT ] ;
    do
        echo "Keycloak is still not ready yet. Retry in $DELAY_RETRY seconds...."
        COUNTER=$(( COUNTER + 1 ))
        sleep $DELAY_RETRY
        URL=http://$PRIMARY_INSTANCE:8070/auth/realms/id3-license/.well-known/openid-configuration
        HTTP_CODE_KEYCLOAK=$(curl -sIk $URL | grep "HTTP/1.1" | awk {'print $2'})
        TOTAL_TIME=$(( DELAY_RETRY*COUNTER ))
    done
    if [ "$HTTP_CODE_KEYCLOAK" = "200" ]
    then
        echo "${GREEN}Keycloak is now ready : OK${NC}\n"
    else
        echo "${RED}ERROR : Keycloak cannot be started... Please contact the support.${NC}"
        exit 1
    fi
fi

echo "Restart Docker now... to finalize setup. Please wait."
sudo systemctl restart docker
echo "${GREEN}Docker is restarted... OK${NC}\n"

if [ $primary = 1 ]
then
    URL=http://$PRIMARY_INSTANCE:8070/auth/realms/id3-license/.well-known/openid-configuration
else
    URL=http://localhost:7002/api/application
fi

COUNTER=0
DELAY_RETRY=5
PROCESS_TIMEOUT=150
TOTAL_TIME=0
HTTP_CODE=""

echo "Waiting for the application to be ready..."
while [ "$HTTP_CODE" != "200" ] && [ $TOTAL_TIME -le $PROCESS_TIMEOUT ] ;
do
    echo "Application is still not ready yet. Retry in $DELAY_RETRY seconds...."
    COUNTER=$(( COUNTER + 1 ))
    sleep $DELAY_RETRY
    HTTP_CODE=$(curl -sIk $URL | grep "HTTP/1.1" | awk {'print $2'})
    TOTAL_TIME=$(( DELAY_RETRY*COUNTER ))
done
if [ "$HTTP_CODE" = "200" ]
then
    echo "${GREEN}Application is now ready : Setup process is finish. SUCCESS.${NC}"
else
    echo "${RED}ERROR : Application cannot be started... Please contact the support.${NC}"
    exit 1
fi