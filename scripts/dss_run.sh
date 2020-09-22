#!/bin/bash


function err_exit {
    echo 'err_exit'
    echo "$ERROR_FLAG Task $1 exited with code $2";
    exit $2;
}

# Override config parameters if container launced with corresponding ENVVARS (all have prefix DSS_)
function encryptiontool_config {
    echo 'encryptiontool_config'
    sed -i "s/___DSSIV___/$1/g" $DSS_ROOT/encryptionutility/resource/encryption.properties
}

function dsswebserver_config {
    echo 'dsswebserver_config'
    # DSSWebServer Config
    # Credentials will be pulled from SSM
    if [ !  -z $DSS_DSSWEBSERVERURL ]; then
        # URL requires a diff seperator for sed
        # 's/url=https:\/\/localhost:8080/url=https:\/\/interface-app-internal.stage.delius.probation.hmpps.dsd.io\/NDeliusDSS\/UpdateOffender/g'
        echo "updating dsswebserver url=$DSS_DSSWEBSERVERURL"
        sed -i "s#url=https://localhost:8080#url=$DSS_DSSWEBSERVERURL#g" $DSS_ROOT/offloc/DSSWebService.properties.template
    fi
    echo 'Fetch per env SSM Creds - username'
    sed -i "s/username=___CHANGEME___/username=$1/g" $DSS_ROOT/offloc/DSSWebService.properties.template
    echo 'Fetch per env SSM Creds - password'
    sed -i "s/password=___CHANGEME___/password=$2/g" $DSS_ROOT/offloc/DSSWebService.properties.template
    
    echo "$DSS_ROOT/offloc/DSSWebService.properties.template"
    cat $DSS_ROOT/offloc/DSSWebService.properties.template | grep url
    cat $DSS_ROOT/offloc/DSSWebService.properties.template | grep username
}

function hmpsserver_config {
    echo 'hmpsserver_config'
    if [ !  -z $DSS_HMPSSERVERURL ]; then
        # URL requires a diff seperator for sed
        echo "updating hmpsserver url=$DSS_HMPSSERVERURL"
        sed -i "s#url=https:\/\/localhost:8080#url=$DSS_HMPSSERVERURL#g" $DSS_ROOT/offloc/HMPSServerDetails.properties.template
    fi
    echo 'Fetch per env SSM Creds - username'
    sed -i "s/username=___CHANGEME___/username=$1/g" $DSS_ROOT/offloc/HMPSServerDetails.properties.template
    echo 'Fetch per env SSM Creds - password'
    sed -i "s/password=___CHANGEME___/password=$2/g" $DSS_ROOT/offloc/HMPSServerDetails.properties.template
}

function filetransfer_config {
    echo 'filetransfer_config'
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
        # sed -i "s/test.offloc.file.path/test.mode=$DSS_TESTFILE/g" $CONF
        sed -i "s/test.offloc.file.path=\/dss_artefacts\/test_file.zip/test.offloc.file.path=\/dss_artefacts\/$DSS_TESTFILE/g" $CONF
    fi
    sed -i "s/___DSSIV___/$1/g" $CONF
}

function fileimporter_config {
    echo 'fileimporter_config'
    sed -i "s/___DSSIV___/$1/g" $DSS_ROOT/fileimporter/resource/FileImporter.properties
}

function check_log_errors {
    echo 'check_log_errors'
    FATALERRORSFILENAME='./fatalerrors.txt'
    grep FATAL $1 | tr -d '"' > $FATALERRORSFILENAME

    # max number of parse errors to fail the job on
    PARSEERRORMAXLIMIT=10
    # if we pass in override as env var PARSEERRORMAXLIMITOVERRIDE update to use this override
    if [ ! -z $PARSEERRORMAXLIMITOVERRIDE ]; then
        PARSEERRORMAXLIMIT=$PARSEERRORMAXLIMITOVERRIDE
    fi
    # track number of FATAL errors in this file not ones we expect (parser)
    FATALERRORCOUNTNOTAPARSEERROR=0
    LINEPARSEERRORCOUNT=0

    while read line; do
        echo "Checking Line: $line"
        if [ $(echo $line | grep 'An\|exception\|occurred\|when\|parsing\|data\|in\|P-NOMIS\|file\|at\|line\|number' | wc -l) -eq 0 ]; then
            echo "Fatal errors detected other than line parse error"
            FATALERRORCOUNTNOTAPARSEERROR=$((FATALERRORCOUNTNOTAPARSEERROR+1))
        else
            echo "Line parse error detected, ignore this error unless we get >= $PARSEERRORMAXLIMIT occurrence. "
            LINEPARSEERRORCOUNT=$((LINEPARSEERRORCOUNT+1))
        fi
        # echo "Line check completed."
    done < "$FATALERRORSFILENAME"

    echo "FATALERRORCOUNTNOTAPARSEERROR: $FATALERRORCOUNTNOTAPARSEERROR"
    echo "PARSEERRORMAXLIMIT:  $PARSEERRORMAXLIMIT"
    echo "LINEPARSEERRORCOUNT: $LINEPARSEERRORCOUNT"

    if [ "$FATALERRORCOUNTNOTAPARSEERROR" -gt 0 ]; then
        echo "Fatal errors detected in $1 that were not parse errors"
    else
        echo "No Fatal errors detected in $1 that were not parse errors"
        if [ "$LINEPARSEERRORCOUNT" -ge "$PARSEERRORMAXLIMIT" ]; then
            echo "Fatal parse error count of $LINEPARSEERRORCOUNT is >= limit of $PARSEERRORMAXLIMIT in file $1"
            err_exit $1 2
        else
            echo "Fatal parse error count of $LINEPARSEERRORCOUNT is less than limit of $PARSEERRORMAXLIMIT in file $1"
        fi
    fi
}

# function main {}
DSS_ROOT=/dss
# Use keyword flags in exit codes to allow Cloudwatch Log Metrics to be defined
SUCCESS_FLAG="DSS_SUCCESS"
ERROR_FLAG="DSS_ERROR"

if [ -z $DSS_AWSREGION ]; then  
    DSS_AWSREGION="eu-west-2"
fi

if [ -z $DSS_PROJECT ]; then
    DSS_PROJECT="delius"
fi

# env

# Only fetch params if not in build environment
echo "DSS_TESTMODE = $DSS_TESTMODE"
if [ ! $DSS_TESTMODE  ]; then
    # Get list of params in this region that match predetermined path
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
else
    echo "DSS_TESTMODE is true so skipping fetch of parameter store parameters."
fi

# Generate random 16byte Initialisation vector
IV=$(strings /dev/urandom | grep -o '[[:alnum:]]' | head -n 16 | tr -d '\n'; echo)
echo $IV

# Set config values
dsswebserver_config $DSS_WEB_USER $DSS_WEB_PASSWORD
hmpsserver_config $PNOMIS_WEB_USER $PNOMIS_WEB_PASSWORD
encryptiontool_config $IV
filetransfer_config $IV
fileimporter_config $IV

# Encrypt sensitive files
echo 'Encrypt sensitive files'
cd $DSS_ROOT/encryptionutility
java -cp ./*:lib/*:encryptionutility.jar:resource uk.co.bconline.ndelius.dss.common.impl.CredentialsGenerator ../offloc/DSSWebService.properties.template ../offloc/DSSWebService.properties ../offloc/DSSWebService.keyfile
java -cp ./*:lib/*:encryptionutility.jar:resource uk.co.bconline.ndelius.dss.common.impl.CredentialsGenerator ../offloc/HMPSServerDetails.properties.template ../offloc/HMPSServerDetails.properties ../offloc/HMPSServerDetails.keyfile

echo 'generate enc props file'
if [ ! -f $DSS_ROOT/offloc/DSSWebService.keyfile ] && [ ! -f $DSS_ROOT/offloc/DSSWebService.properties ]; then
    echo "Error - Failed to generate encrypted properties file for DSSWebService"
    err_exit DSSWebServiceEnryption 4
elif [ ! -f $DSS_ROOT/offloc/HMPSServerDetails.keyfile ] && [ ! $DSS_ROOT/offloc/HMPSServerDetails.properties ]; then ]
    echo "Error - Failed to generate encrypted properties file for HMPSServerDetails"
    err_exit HMPPSServerDetailsEncrytion 5
fi

# If build flag is passed, then do not proceed with actually running the dss batch task
if [ "$DSS_TESTMODE" == "true" ]; then
    echo "DSS_SUCCESS Ending run as build flag passed. Exiting..."
    sleep 10
    exit 0
fi

# Run the File transfer first
cd $DSS_ROOT/filetransfer 
java -cp filetransfer.jar:resource uk.co.bconline.ndelius.dss.filetransfer.FileTransfer
FTRESULT=$?

# check filetransfer was successful - there's a file
OFFLOCFILEPATH=$(grep "^offloc.file.path" /dss_config/FileTransfer.properties | cut -d '=' -f 2)
echo "Checking file download '$OFFLOCFILEPATH' exists to confirm if downloaded offloc file exists.."
ls -al $OFFLOCFILEPATH
if test -f "$OFFLOCFILEPATH"; then
    echo "$OFFLOCFILEPATH exists."
else
    echo "'$OFFLOCFILEPATH' does not exists so there was an issue with file transfer."
    err_exit FileTransfer 2
fi

# Wait for FI to finish
while [ $(ps -o pid,args | grep "fileimporter.jar" | grep -v grep | awk '{print $1}'|wc -l) -gt 0 ] ; do 
    echo "Waiting for FileImporter process to finish"; 
    sleep 10; 
done
# FileTransfer logs are output to stdout/stderr, but the child FileImporter logs are only written to file - print it for Cloudwatch
echo "FileImporter Logs follow:"
cat /dss/fileimporter/fileimporter.log

echo "FT Result == $FTRESULT"
if [ $FTRESULT -eq 0 ]; then
    echo "Checking logs for errors..."
    # check_log_errors /dss/filetransfer/filetransfer.log
    check_log_errors /dss/fileimporter/fileimporter.log
else
    err_exit FileTransfer $FTRESULT
fi

# If still here - all good
echo "$SUCCESS_FLAG - Task Ran Successfully"
exit 0