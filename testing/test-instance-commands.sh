
#!/bin/bash

#  docker
sudo amazon-linux-extras install docker
sudo service docker start
sudo usermod -a -G docker ec2-user

# jq
sudo yum install jq -y

sudo su 
$(aws ecr get-login --no-include-email --region eu-west-2 --registry-ids 895523100917)
aws --region eu-west-2 ecr describe-repositories --registry-id 895523100917 --repository-names "hmpps/dss" | jq -r .repositories[0].repositoryUri > ecr.repo


export DOCKER_IMAGE_VERSION=3.1.5
docker pull 895523100917.dkr.ecr.eu-west-2.amazonaws.com/hmpps/dss:${DOCKER_IMAGE_VERSION}

export DSS_AWSREGION=eu-west-2
export DSS_TESTMODE=false
export DSS_ENVIRONMENT=delius-stage
export DSS_PROJECT=delius
export DSS_DSSWEBSERVERURL=https://interface-app-internal.stage.delius.probation.hmpps.dsd.io/NDeliusDSS/UpdateOffender
export DSS_HMPSSERVERURL=https://www.offloc.service.justice.gov.uk/
export DSS_TESTINGAUTOCORRECT=true
export JAVA_OPTS="-Xms1024m -Xmx2048m"

#bash
docker run -it -e DSS_AWSREGION=${DSS_AWSREGION} -e DSS_TESTMODE=${DSS_TESTMODE} -e DSS_ENVIRONMENT=${DSS_ENVIRONMENT} -e DSS_PROJECT=${DSS_PROJECT} -e DSS_DSSWEBSERVERURL=${DSS_DSSWEBSERVERURL} -e DSS_HMPSSERVERURL=${DSS_HMPSSERVERURL} -e DSS_TESTINGAUTOCORRECT=${DSS_TESTINGAUTOCORRECT} -e JAVA_OPTS="${JAVA_OPTS}" 895523100917.dkr.ecr.eu-west-2.amazonaws.com/hmpps/dss:${DOCKER_IMAGE_VERSION} bash

# dss_run.sh
docker run -e DSS_AWSREGION=${DSS_AWSREGION} -e DSS_TESTMODE=${DSS_TESTMODE} -e DSS_ENVIRONMENT=${DSS_ENVIRONMENT} -e DSS_PROJECT=${DSS_PROJECT} -e DSS_DSSWEBSERVERURL=${DSS_DSSWEBSERVERURL} -e DSS_HMPSSERVERURL=${DSS_HMPSSERVERURL} -e DSS_TESTINGAUTOCORRECT=${DSS_TESTINGAUTOCORRECT} -e JAVA_OPTS="${JAVA_OPTS}" 895523100917.dkr.ecr.eu-west-2.amazonaws.com/hmpps/dss:${DOCKER_IMAGE_VERSION}