#!/bin/bash
set -e

# pass the dataset name as the first argument
export DATASET="${1}"
 
echo "Transform the data for ${DATASET} using LD-workbench..."

docker compose run --rm map /bin/sh -c "ld-workbench --config /pipelines"

OUTPUT_FILE="./ld-workbench/${DATASET}.nt"

if [ -f $OUTPUT_FILE ]; then
  # mv the output file to the dataset root if the mapping was succesful
  # TODO create a shared volume in docker-compose ??
  mv $OUTPUT_FILE ./data/${DATASET}.nt
else
  echo "Error: Mapping failed, no output file"
  exit 1
fi

