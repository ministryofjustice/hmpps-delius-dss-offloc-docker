

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

docker run -it -e DSS_ENVIRONMENT=delius-stage -e DSS_DSSWEBSERVERURL=https://server.local:8080 
-e AWS_PROFILE=${AWS_PROFILE} -v `pwd`/scripts/dss_run.sh:/dss_scripts/dss_run.sh 
 895523100917.dkr.ecr.eu-west-2.amazonaws.com/hmpps/dss:3.1

