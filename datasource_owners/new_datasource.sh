#!/bin/bash

## HORTIVATION HUB DATA SOURCE CREATION
#
# Copyright 2022 Sobolt B.V.
#
# DESCRIPTION
# 
# Hortivation Hub is a data exchange platform that aims to standardise communication between 
# different parties in the Greenhouse Technology Sector. Dataset sharing across the platform 
# is enabled by the Hortivation Hub Data Source, which is a server that is hosted by dataset 
# owners. 
# 
# This script allows easy sharing of Greenhouse dataset(s). It connects your data source server
# with the hortivation hub portal, where the authorised personnel and organisations can access 
# components of entire shared datasets within this data source.
# 
# REQUIREMENTS: 
#  - Debian based x86/64 machine
#  - HTTP/HTTPS traffic allowed
#  - CGO compliant Dataset files accessible to the script (.ttl)
#  - Data Source credential .json file (provided after registering the data source on the hub portal)
#  - 
# 
# USAGE:
# On data source server, connect the datasets with the portal as follows:
#       bash new_datasource.sh -d PATH/TO/DATASET_FOLDER -c PATH/TO/DATASOURCE_CREDENTIALS_JSON
# Run with verbose flag if needed
#       bash new_datasource.sh -d PATH/TO/DATASET_FOLDER -c PATH/TO/DATASOURCE_CREDENTIALS_JSON -v
# Help 
#       bash new_datasource.sh -h[--help]



## Exit if a command exits with a non-zero status.
set -e


## usage function
usage() { echo "Usage: bash $0 -d PATH/TO/DATASET_FOLDER -c PATH/TO/DATASOURCE_CREDENTIALS_JSON -v" 1>&2; exit 1; }

## read arguments
while getopts ":d:c:vh" args; do
    case "${args}" in
        d)
            DATASOURCE_FOLDER=${OPTARG}
            ;;
        c)
            CREDENTIALS=${OPTARG}
            ;;
        v)
            verbose='true'
            ;;
        h)
            usage
            ;;
        *)
            echo "Arguments not provided properly!"
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${DATASOURCE_FOLDER}" ] || [ -z "${CREDENTIALS}" ]; then
    echo "One or more required arguments missing!"
    usage
fi

## 0. DISPLAY RUN OPTIONS ##

echo "Connecting datasets in ${DATASOURCE_FOLDER}"
echo "Using Data Source credentials file: ${CREDENTIALS}"
if [ -z "${verbose}" ]; then
    echo "Running silently!"
else
    echo "Running verbosely!"
fi

## 1. INSTALL DEPENDENCIES ##

# 1.1 docker
sudo apt-get remove docker docker-engine docker.io containerd runc
sudo apt-get update
sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker $USER
docker_version=$(docker --version | cut -d " " -f 3 | cut -d "," -f 1)
if [ verbose == 'true' ]; then
    echo "docker ${docker_version} installed"
fi

# 1.2 docker-compose 1.29.2
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
compose_version=$(docker-compose --version | cut -d " " -f 3 | cut -d "," -f 1)
if [ verbose == 'true' ]; then
    echo "docker-compose ${compose_version} installed"
fi

# 1.3 YQ for parsing yaml files
snap install yq


## 2. PREPARE  ##

# 2.1  Clone template repository
git clone https://github.com/Hortivation/getting-started.git
# set working directory
cd getting-started/datasource_owners

# 2.2 Remove template data & copy real datasets to the required repository folder
rm datasets/dataset1/data.ttl
cp -r ${DATASOURCE_FOLDER}/* datasets/dataset1/
# check data file extension
for file in datasets/dataset1/; do
    if [[ "${file: -4}" == "*.ttl" ]];
    then
        echo "File: ${file} does not have .ttl extension."
        exit 1
    fi
done;


# 2.2 Copy the credentials json to the server
cp ${CREDENTIALS} ./
JSON_FILE=$(find . -name "*.json")

# 2.3 Take inputs for the datasource description yml
echo "Add a description for the data source!"

read -p "Provide a name for the data set being shared!`echo $'\n> '`" dataset_name
echo "dataset name: ${dataset_name}"
sleep 0.5
read -p "Provide a description for the data set!`echo $'\n> '`" dataset_description
echo -e "description provided:\n ${dataset_description}"
sleep 0.5 
read -p "Provide any additional information!`echo $'\n> '`" dataset_add_info
echo -e "additional information:\n ${dataset_add_info}"
sleep 0.5
read -p "Provide name of the contact person!`echo $'\n> '`" contact_person
echo "Contact person: ${contact_person}"
sleep 0.5
read -p "Provide email of the contact person!`echo $'\n> '`" contact_email
echo "Contact email: ${contact_email}"
sleep 0.5
read -p "File type ('file' or 'fuseki'). Defaults to 'file'!`echo $'\n> '`" file_type
echo "File type: ${file_type}"
sleep 0.5
read -p "Dataset to be shared: ${file}. Is this correct? [y/n]! " path_correct
case $path_correct in 
	y ) echo "connecting data source" ;;
	n ) echo "Entered No. Exiting...";
		exit;;
	* ) echo "invalid response";
		exit 1;;
esac
sleep 0.5

# 2.4 update the description file based on above input
NAME=$dataset_name DESC=$dataset_description INFO=$dataset_add_info \
    PERSON_CONTACT="${contact_person}, ${contact_email}" TYPE=$file_type FPATH=$file \
    yq -n ' 
        .[env(NAME)].about = env(DESC) |
        .[env(NAME)].additional_info = env(INFO) |
        .[env(NAME)].contact = env(PERSON_CONTACT) |
        .[env(NAME)].type = env(TYPE) |
        .[env(NAME)].path = env(FPATH)
        ' > datasource_description.yaml


## 3.0 RUN ##

# run the compose up to bring the data source online
# this can take a few minutes
HOSTNAME=${HOSTNAME} CREDENTIALS=${JSON_FILE} docker-compose up -d