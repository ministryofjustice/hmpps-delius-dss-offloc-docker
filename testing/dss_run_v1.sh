#!/bin/bash

DSS_ROOT=/dss
# Use keyword flags in exit codes to allow Cloudwatch Log Metrics to be defined
SUCCESS_FLAG="DSS_SUCCESS"
ERROR_FLAG="DSS_ERROR"

if [ -z $DSS_AWSREGION ]; then
    DSS_AWSREGION="eu-west-2"
fi

if [ -z $DSS_PROJECT ]; then
    DSS_PROJECT="delius"
fi

if [ -z $JAVA_OPTS ]; then
    JAVA_OPTS="-Xms128m -Xmx256m"
fi

function err_exit {
    echo "$ERROR_FLAG Task $1 exited with code $2";
    exit $2;
}

# Override config parameters if container launced with corresponding ENVVARS (all have prefix DSS_)
function encryptiontool_config {
    sed -i "s/___DSSIV___/$1/g" $DSS_ROOT/encryptionutility/resource/encryption.properties
}

function dsswebserver_config {
    # DSSWebServer Config
    # Credentials will be pulled from SSM
    if [ !  -z $DSS_DSSWEBSERVERURL ]; then
        # URL requires a diff seperator for sed
        sed -i "s#url=https:\/\/localhost:8080#url=$DSS_DSSWEBSERVERURL#g" $DSS_ROOT/offloc/DSSWebService.properties.template
    fi
    # Fetch per env SSM Creds
    sed -i "s/username=___CHANGEME___/username=$1/g" $DSS_ROOT/offloc/DSSWebService.properties.template
    sed -i "s/password=___CHANGEME___/password=$2/g" $DSS_ROOT/offloc/DSSWebService.properties.template
}

function hmpsserver_config {
    if [ !  -z $DSS_HMPSSERVERURL ]; then
        # URL requires a diff seperator for sed
        sed -i "s#url=https:\/\/localhost:8080/testfile.zip#url=$DSS_HMPSSERVERURL#g" $DSS_ROOT/offloc/HMPSServerDetails.properties.template
    fi
    # Fetch per env SSM Creds
    sed -i "s/username=___CHANGEME___/username=$1/g" $DSS_ROOT/offloc/HMPSServerDetails.properties.template
    sed -i "s/password=___CHANGEME___/password=$2/g" $DSS_ROOT/offloc/HMPSServerDetails.properties.template
}

function filetransfer_config {
    CONF=$DSS_ROOT/filetransfer/resource/FileTransfer.properties

    if [ ! -z $DSS_PNOMISFILEEXTENSION ]; then
        sed -i "s/pnomis.file.extension=dat/pnomis.file.extension=$DSS_PNOMISFILEEXTENSION/g" $CONF
    fi
    if [ ! -z $DSS_FILEIMPORTERSTARTUPCMD ]; then
        sed -i "s/file.importer.startup.command=java -Xms256m -Xmx512m -cp fileimporter.jar:resource uk.co.bconline.ndelius.dss.fileimporter.FileImporter/$DSS_DSS_FILEIMPORTERSTARTUPCMD/g" $CONF
    fi
    if [ ! -z $DSS_TESTINGAUTOCORRECT ]; then
        sed -i "s/offloc.testing.autocorrect=true/offloc.testing.autocorrect=$DSS_TESTINGAUTOCORRECT/g" $CONF
    fi
    if [ ! -z $DSS_TESTMODE ]; then
        sed -i "s/test.mode=false/test.mode=$DSS_TESTMODE/g" $CONF
    fi
    if [ ! -z $DSS_TESTFILE ]; then
        sed -i "s/test.offloc.file.path/test.mode=$DSS_TESTFILE/g" $CONF
    fi
    sed -i "s/___DSSIV___/$1/g" $CONF
}

function fileimporter_config {
    sed -i "s/___DSSIV___/$1/g" $DSS_ROOT/fileimporter/resource/FileImporter.properties
}

function check_log_errors {
    if [ $(grep FATAL $1 | wc -l) -gt 0 ]; then
        echo "Fatal errors detected in $1"
        err_exit $1 2
    fi
}

# Only fetch params if not in build environment
if [ -z $DSS_BUILDTESTMODE ]; then
    # Get list of params in this region that match predetermined path
    echo "Fetching DSS credentials from SSM..."
    DSS_PARAMS_JSON=$(aws ssm get-parameters --names "/$DSS_ENVIRONMENT/$DSS_PROJECT/apacheds/apacheds/dss_user" "/$DSS_ENVIRONMENT/$DSS_PROJECT/apacheds/apacheds/dss_user_password" --with-decryption --region $DSS_AWSREGION)
    # Expect 2 keys
    if [ $(echo $DSS_PARAMS_JSON | jq -r '.Parameters | length') -ne 2 ] || [ "$DSS_PARAMS_JSON" == "" ]; then
        echo "Fatal - failed to retrieve required DSS SSM Parameters.";
        err_exit FetchSSMParameters 3
    fi
    DSS_WEB_USER=$(echo $DSS_PARAMS_JSON | jq -r '.Parameters[] | select(.Name | contains("dss_user"))| .Value ')
    DSS_WEB_PASSWORD=$(echo $DSS_PARAMS_JSON | jq -r '.Parameters[] | select(.Name | contains("dss_user_password"))| .Value ')

    echo "Fetching PNOMIS credentials from SSM..."
    PNOMIS_PARAMS_JSON=$(aws ssm get-parameters --names "/$DSS_ENVIRONMENT/$DSS_PROJECT/dss/dss/pnomis_web_user" "/$DSS_ENVIRONMENT/$DSS_PROJECT/dss/dss/pnomis_web_password" --with-decryption --region $DSS_AWSREGION)
    # Expect 2 keys
    if [ $(echo $PNOMIS_PARAMS_JSON | jq -r '.Parameters | length') -ne 2 ] || [ "$PNOMIS_PARAMS_JSON" == "" ]; then
        echo "Fatal - failed to retrieve required PNOMIS SSM Parameters.";
        err_exit FetchSSMParameters 3
    fi
    PNOMIS_WEB_USER=$(echo $PNOMIS_PARAMS_JSON | jq -r '.Parameters[] | select(.Name | contains("pnomis_web_user"))| .Value ')
    PNOMIS_WEB_PASSWORD=$(echo $PNOMIS_PARAMS_JSON | jq -r '.Parameters[] | select(.Name | contains("pnomis_web_password"))| .Value ')
    echo "Credentials retrieved successfully."
fi

# Generate random 16byte Initialisation vector
IV=$(strings /dev/urandom | grep -o '[[:alnum:]]' | head -n 16 | tr -d '\n'; echo)

# Set config values
echo "Updating dsswebserver_config..."
dsswebserver_config $DSS_WEB_USER $DSS_WEB_PASSWORD
echo "Updating hmpsserver_config..."
hmpsserver_config $PNOMIS_WEB_USER $PNOMIS_WEB_PASSWORD
echo "Updating encryptiontool_config..."
encryptiontool_config $IV
echo "Updating filetransfer_config..."
filetransfer_config $IV
echo "Updating fileimporter_config..."
fileimporter_config $IV

# Encrypt sensitive files
cd $DSS_ROOT/encryptionutility
java -cp ./*:lib/*:encryptionutility.jar:resource uk.co.bconline.ndelius.dss.common.impl.CredentialsGenerator ../offloc/DSSWebService.properties.template ../offloc/DSSWebService.properties ../offloc/DSSWebService.keyfile
java -cp ./*:lib/*:encryptionutility.jar:resource uk.co.bconline.ndelius.dss.common.impl.CredentialsGenerator ../offloc/HMPSServerDetails.properties.template ../offloc/HMPSServerDetails.properties ../offloc/HMPSServerDetails.keyfile

if [ ! -f $DSS_ROOT/offloc/DSSWebService.keyfile ] && [ ! -f $DSS_ROOT/offloc/DSSWebService.properties ]; then
    echo "Error - Failed to generate encrypted properties file for DSSWebService"
    err_exit DSSWebServiceEnryption 4
elif [ ! -f $DSS_ROOT/offloc/HMPSServerDetails.keyfile ] && [ ! $DSS_ROOT/offloc/HMPSServerDetails.properties ]; then ]
    echo "Error - Failed to generate encrypted properties file for HMPSServerDetails"
    err_exit HMPPSServerDetailsEncrytion 5
fi

# If build flag is passed, then do not proceed with actually running the dss batch task
if [ "$DSS_BUILDTESTMODE" == "true" ]; then
    echo "DSS_SUCCESS Ending run as build flag passed. Exiting..."
    sleep 30
    exit 0
fi

# Run the File transfer first
cd $DSS_ROOT/filetransfer
java $JAVA_OPTS -Dcom.sun.jndi.ldap.object.disableEndpointIdentification=true -cp filetransfer.jar:resource uk.co.bconline.ndelius.dss.filetransfer.FileTransfer
FTRESULT=$?
# Wait for FI to finish
while [ $(ps -o pid,args | grep "fileimporter.jar" | grep -v grep | awk '{print $1}'|wc -l) -gt 0 ] ; do
    echo "Waiting for FileImporter process to finish";
    sleep 10;
done
# FileTransfer logs are output to stdout/stderr, but the child FileImporter logs are only written to file - print it for Cloudwatch
echo "FileImporter Logs folow:"
cat /dss/fileimporter/fileimporter.log

echo "FT Result == $FTRESULT"
if [ $FTRESULT -eq 0 ]; then
    echo "Checking logs for errors..."
    check_log_errors /dss/filetransfer/filetransfer.log
    check_log_errors /dss/fileimporter/fileimporter.log
else
    err_exit FileTransfer $FTRESULT
fi

# If still here - all good
echo "$SUCCESS_FLAG - Task Ran Successfully"
exit 0
