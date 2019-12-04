#!/bin/sh

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

if [ $primary = 1 ]
then
    docker-compose -f docker-compose.yml up -d
else
    docker-compose -f docker-compose.secondary.yml up -d
fi

