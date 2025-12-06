#!/bin/bash
set -e

if [ ! -f environment ]; then
  echo "Error: Environment file doesn't exists. Please rerun the init-pipeline script"
  exit 1
fi

# test value: https://data.beeldengeluid.nl/files/amateurfilm/lod_amateurfilm_sdo_20250806_clean.nt
# read the environment variables
# at least SOURCE_URL or SOURCE_FILE should be set

# clear old values
unset SOURCE_URL SOURCE_FILES

# read the variables from the 'environment' file
source environment

if [ -z "$SOURCE_URL" ] && [ -z "$SOURCE_FILES" ] ; then
   echo "Error: Please set SOURCE_URL or SOURCE_FILES variable in `environment` file"
   exit 1
fi

# if $SOURCE_URL is set a file will be downloaded 
if [ ! -z "$SOURCE_URL" ]; then
  cd data
  file=${SOURCE_URL##*/} 
  echo "Dataset name is: $DATASET"
  echo "Source URL is: $SOURCE_URL"
  echo "Starting download..."
  if ! wget -nc -o download-log.txt $SOURCE_URL; then
     echo ""
  fi

  # check if the download was succesful; else terminate the script
  if grep -wq "ERROR" download-log.txt; then 
      echo "ERROR in download" 
      rm $file
      cd ..
      exit 1
  fi

  case "$file" in
    *.tar.gz)
      echo "Extracting files..."  
      tar xfz $file ;;
    *.tgz)
      echo "Extracting files..." 
      tar xfz $file ;;
    *.gz)
       echo "Extracting files..."   
      gunzip $file ;;
    *.zip)
      echo "Extracting files..."
      unzip $file ;;
    *.nt)
      echo "no extra processing needed" ;;
    *)
    echo "unsupported file format, please prepare download files manualy" 
    exit 1 ;;
  esac

  # remove orginal downloaded file
  rm $file

  # TODO: support other RDF-serializations
  echo "Looking for N-triples files to proces..."
  dataFiles=(*.nt)

  # Convert the array to a string with a delimiter
  dataFilesString=$(IFS=:; echo "${dataFiles[*]}")

  cd ..

  export SOURCE_FILES_DOWNLOADED=$dataFilesString
  envsubst < environment > tmp.env 
  mv tmp.env environment
  echo "Download succeeded, SOURCE_FILES variable set!"

fi 

source environment

# copy the data file to fuseki map to make it available for docker
# TODO: create a shared volume through docker-compose
echo "Copy the data files to the Fuseki environment"
cp ./data/*.nt ./fuseki

echo "Creating the Fuseki config file"

# create a local copy of the fuseki config file
envsubst < ../generic/fuseki-config.ttl > ./fuseki/config.ttl

## expand the fuseki config file with additional lines to link the data files 
echo "<#dataset> rdf:type ja:MemoryDataset ;" >> ./fuseki/config.ttl

# read the SOURCE_FILES variable into an array
# loop over the array to create a config line for each file 
IFS=: read -r -a dataFiles <<< "$SOURCE_FILES"

# get length of an array
arraylength=${#dataFiles[@]}

# use for loop to read all values and indexes
for (( i=0; i<${arraylength}; i++ ));
do
  echo "  ja:data \"./data/${dataFiles[$i]}\" ;" >> ./fuseki/config.ttl
done

# close the config file with a "." to terminate the triples
echo "  ." >> ./fuseki/config.ttl

# update LD-Workbench configuration based on the environment variables
envsubst < ../generic/ld-workbench-config.yml > ld-workbench/config.yml

echo "Configuration done!"


