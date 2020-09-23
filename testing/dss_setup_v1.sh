#!/bin/sh

set -x

# This script prepares a base DSS Client environment, including template config files
# Addiional config is generated/loaded at run time via the dss_run.sh script
if [ -z $DSS_VERSION ]; then
    if [ -z $1 ]; then
        DSS_VERSION=$1
    else
        echo "DSS_VERSION Environment Variable not set"
        exit 1
    fi
fi

# Download versioned artefacts
AWSCLI=$(which aws)

cd /dss_artefacts

# TODO Workaround for FileImporter not following redirects issue
$AWSCLI s3 cp s3://tf-eu-west-2-hmpps-eng-dev-delius-core-dependencies-s3bucket/dependencies/delius-core/OFFLOC/NDelius-DSS-FileImporter-3.0-FI.zip NDelius-DSS-FileImporter-$DSS_VERSION-FI.zip

# Fetch test data file from S3
$AWSCLI s3 cp s3://tf-eu-west-2-hmpps-eng-dev-delius-core-dependencies-s3bucket/dependencies/delius-core/OFFLOC/test_file.zip .

# Set up app dirs and Unzip deployment artefacts
cd /dss
mkdir -p offloc fileimporter filetransfer encryptionutility encryptionutility/resource outputs testfile
unzip /dss_artefacts/NDelius-DSS-EncryptionUtility-$DSS_VERSION-EU.zip -d encryptionutility/
unzip /dss_artefacts/NDelius-DSS-FileTransfer-$DSS_VERSION-FT.zip -d filetransfer/
unzip /dss_artefacts/NDelius-DSS-FileImporter-$DSS_VERSION-FI.zip -d fileimporter/

# Handle incorrectly named artefact
if [ -f fileimporter/\$fileimporter.jar ]; then
    mv fileimporter/\$fileimporter.jar fileimporter/fileimporter.jar;
fi

# Copy template files into place
cp /dss_config/DSSWebService.properties offloc/DSSWebService.properties.template
cp /dss_config/FileTransfer.properties filetransfer/resource/FileTransfer.properties
cp /dss_config/FileImporter.properties fileimporter/resource/FileImporter.properties
cp /dss_config/encryption.properties encryptionutility/resource/encryption.properties
cp /dss_config/HMPSServerDetails.properties.template offloc/HMPSServerDetails.properties.template

# Remove remote log4j appender config
xmlstarlet ed -L -d '//root' /dss/fileimporter/resource/log4j.xml
xmlstarlet ed -L -d '//root' /dss/filetransfer/resource/log4j.xml
xmlstarlet ed -L -d '//appender[@name = "socketNode"]' /dss/fileimporter/resource/log4j.xml
xmlstarlet ed -L -d '//appender[@name = "socketNode"]' /dss/filetransfer/resource/log4j.xml
xmlstarlet ed -L -d '//appender[@name = "asyncSocketNode"]' /dss/fileimporter/resource/log4j.xml
xmlstarlet ed -L -d '//appender[@name = "asyncSocketNode"]' /dss/filetransfer/resource/log4j.xml

# Set consistent file permissions across DSS builds
chmod 0640 /dss/filetransfer/filetransfer.jar
chmod 0640 /dss/filetransfer/resource/FileTransfer.properties
chmod 0640 /dss/encryptionutility/encryptionutility.jar
chmod 0640 /dss/encryptionutility/resource/encryption.properties
chmod 0640 /dss/fileimporter/fileimporter.jar
chmod 0640 /dss/fileimporter/resource/FileImporter.properties

exit 0