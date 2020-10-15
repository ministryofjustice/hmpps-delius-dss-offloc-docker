#!/bin/sh

set -x

# This script prepares a base DSS envronment, including template config files
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
#list current aws configuration
env
$AWSCLI configure list
$AWSCLI sts get-caller-identity

$AWSCLI s3 ls s3://tf-eu-west-2-hmpps-eng-dev-delius-core-dependencies-s3bucket/dependencies/delius-core/NDelius-$DSS_VERSION/EIS/

ls -al 

$AWSCLI s3 cp s3://tf-eu-west-2-hmpps-eng-dev-delius-core-dependencies-s3bucket/dependencies/delius-core/NDelius-$DSS_VERSION/EIS/NDelius-DSS-EncryptionUtility-$DSS_VERSION-EU.zip .
$AWSCLI s3 cp s3://tf-eu-west-2-hmpps-eng-dev-delius-core-dependencies-s3bucket/dependencies/delius-core/NDelius-$DSS_VERSION/EIS/NDelius-DSS-FileTransfer-$DSS_VERSION-FT.zip .
$AWSCLI s3 cp s3://tf-eu-west-2-hmpps-eng-dev-delius-core-dependencies-s3bucket/dependencies/delius-core/OFFLOC/test_file.zip .
# TODO Workaround for FileImporter not following redirects issue
#$AWSCLI s3 cp s3://tf-eu-west-2-hmpps-eng-dev-delius-core-dependencies-s3bucket/dependencies/delius-core/NDelius-$DSS_VERSION/EIS/NDelius-DSS-FileImporter-$DSS_VERSION-FI.zip .
$AWSCLI s3 cp s3://tf-eu-west-2-hmpps-eng-dev-delius-core-dependencies-s3bucket/dependencies/delius-core/OFFLOC/NDelius-DSS-FileImporter-3.0-FI.zip NDelius-DSS-FileImporter-$DSS_VERSION-FI.zip

ls -al 

