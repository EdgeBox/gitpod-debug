#!/usr/bin/env bash
# see https://carstenwindler.de/php/enable-xdebug-on-demand-in-your-local-docker-environment/

if [ "$#" -lt 1 ]; then
    SCRIPT_PATH=`basename "$0"`
    echo "Usage: $SCRIPT_PATH enable|disable"
    exit 1;
fi

# Expects service to be called drupal in docker-compose.yml ...
CONTAINER="drupal"
# ...unless a custom service name is provided.
if [ "$#" -gt 1 ]; then
    CONTAINER="$2"
fi

SERVICE_ID=$(docker-compose ps -q $CONTAINER)

if [ "$1" == "enable" ]; then
    docker exec -i $SERVICE_ID docker-php-ext-enable xdebug
else
    docker exec -i $SERVICE_ID bash -c 'cd /usr/local/etc/php/ && mkdir -p disabled/ && mv conf.d/docker-php-ext-xdebug.ini disabled/'
fi

docker restart $SERVICE_ID

docker exec -i $SERVICE_ID bash -c '$(php -m | grep -q Xdebug) && echo "Status: Xdebug ENABLED" || echo "Status: Xdebug DISABLED"'
