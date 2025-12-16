#!/bin/bash
set -e

# pass the dataset name as the first argument
export DATASET="${1}"

echo -n "`date`: "
echo "Starting the SPARQL server with for ${DATASET}..."

# start with an empty log file for this session
cat /dev/null > fuseki/log.txt

# run the process as the current user
USER=$(id -u):$(id -g)

# TIP: remove --detach option for debugging
docker compose up --detach fuseki

echo "Waiting for the sparql server to be up and running..."
# wait untill the server is up and running
( tail -f -n0 fuseki/log.txt & ) | grep -q "No static content location"

echo -n "`date`: "
echo "Sparql server available!"