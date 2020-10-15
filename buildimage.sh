 #!/bin/bash +x

function print_env() {
    env | sort
}

install_pre_reqs() {
  echo '----------------------------------------------'
  echo "install_pre_reqs(): Install dgoss"
  echo '----------------------------------------------'
  curl -L https://raw.githubusercontent.com/aelsabbahy/goss/master/extras/dgoss/dgoss -o /usr/local/bin/dgoss
  chmod +rx /usr/local/bin/dgoss
}

ecr_login() {
  echo '----------------------------------------------'
  echo "ecr_login()"
  echo '----------------------------------------------'
  eval $(aws --region eu-west-2 ecr get-login --no-include-email)
}

# docker_hub_login() {
#   echo '----------------------------------------------'
#   echo "docker_hub_login()"
#   echo '----------------------------------------------'
#   docker login -u `aws ssm get-parameters --names /jenkins/dockerhub/username --region eu-west-2 | jq -r '.Parameters[0].Value'` -p `aws ssm get-parameters --names /jenkins/dockerhub/password --with-decryption --region eu-west-2 | jq -r '.Parameters[0].Value'`
# }

build() {
    echo '----------------------------------------------'
    echo "build()"
    echo '----------------------------------------------'
    if [[ "${CODEBUILD_GIT_BRANCH}" == "master" ]];then
        #Always force a clean build on master
        make build  dss_version=${DSS_VERSION} image_tag_version=${IMAGE_TAG_VERSION} no-cache=--no-cache
    else
        make build dss_version=${DSS_VERSION} image_tag_version=${IMAGE_TAG_VERSION} 
    fi
}

set_tag_version() {
  # $GITHUB_ACCESS_TOKEN passed in from BuildSpec from SSM Parameter Store
  # $CODEBUILD_GIT_COMMIT passed in from AWS CodeBuild

  
  if [[ "${CODEBUILD_GIT_BRANCH}" == "master" ]];then
    # get latest tag for commit sha
    IMAGE_TAG_VERSION=$(curl -s -u hmpps-jenkins:$GITHUB_ACCESS_TOKEN https://api.github.com/repos/ministryofjustice/hmpps-delius-dss-offloc-docker/tags | jq -r --arg CODEBUILD_GIT_COMMIT "$CODEBUILD_GIT_COMMIT" '[.[] | select(.commit.sha==$CODEBUILD_GIT_COMMIT)][0].name')
  else
    echo 'not master branch so we set timestamped alpha tag'
    TIMESTAMP=$(date +%F-%H-%M-%S)
    echo "TIMESTAMP:${TIMESTAMP}"
    IMAGE_TAG_VERSION="0.0.0-${TIMESTAMP}-alpha" 
  fi
  echo "Setting Tag to ${IMAGE_TAG_VERSION}"
}

# Checks if we are in CI & pushes
# If we're not push echo a polite message
# This stops accidental pushing when testing locally
# @args
# $1 image name
# $2 image tag
docker_push() {
  echo '----------------------------------------------'
  echo "docker_push()"
  echo "docker_push(${1}, ${2})"
  echo '----------------------------------------------'

  local IMAGE_NAME="${1:?}"
  local TAG="${2:?}"
  if [[ $CI = "true" ]];then
    docker push "${IMAGE_NAME}:${TAG}"
    echo "Last exit status: $?"
  else
    echo "Not in CI so not pushing tag"
  fi
}

push_image() {
  echo '----------------------------------------------'
  echo "push_image()"
  echo '----------------------------------------------'
  IMAGE_NAME="hmpps/dss"
  # PUBLIC_IMAGE="mojdigitalstudio/hmpps-dss"
  
  echo '-------------------------------'
  echo "REGISTRY         : ${REGISTRY:?}"
  echo "IMAGE_NAME       : ${IMAGE_NAME}"
  echo "IMAGE_TAG_VERSION: ${IMAGE_TAG_VERSION}"
  # echo "PUBLIC_IMAGE     : ${PUBLIC_IMAGE}"
  echo '-------------------------------'

  echo "docker tag ${REGISTRY:?}/${IMAGE_NAME}:latest ${REGISTRY:?}/${IMAGE_NAME}:${IMAGE_TAG_VERSION}"
  docker tag "${REGISTRY:?}/${IMAGE_NAME}:latest" "${REGISTRY:?}/${IMAGE_NAME}:${IMAGE_TAG_VERSION}"
  
  # echo "docker tag ${REGISTRY:?}/${IMAGE_NAME}:latest ${PUBLIC_IMAGE}:${IMAGE_TAG_VERSION}"
  # docker tag "${REGISTRY:?}/${IMAGE_NAME}:latest" "${PUBLIC_IMAGE}:${IMAGE_TAG_VERSION}"
  
  echo '----------------------------------------------'
  echo "--- Pushing Private ECR Image ${IMAGE_NAME}:${IMAGE_TAG_VERSION} to registry ---"
  echo '----------------------------------------------'
  docker_push "${REGISTRY:?}/${IMAGE_NAME}" "${IMAGE_TAG_VERSION}"

  # echo '----------------------------------------------'
  # echo "--- Pushing Public Docker Hub public Image ${PUBLIC_IMAGE}:${IMAGE_TAG_VERSION} to registry ---"
  # echo '----------------------------------------------'
  # docker_push "${PUBLIC_IMAGE}" "${IMAGE_TAG_VERSION}"

  if [[ "${CODEBUILD_GIT_BRANCH}" == "master" ]];then
    echo '--------------------------------------------------------'
    echo '--- On master branch so pushing latest tag as well ---'
    echo '--------------------------------------------------------'
    docker tag "${IMAGE_NAME}:latest" "${REGISTRY:?}/${IMAGE_NAME}:latest"
    docker_push "${REGISTRY:?}/${IMAGE_NAME}" "latest"
    # docker tag "${IMAGE_NAME}:latest" "${PUBLIC_IMAGE}:latest"
    # docker_push "${PUBLIC_IMAGE}" "latest"
  fi
}

function set_environment_variables() {
    echo '----------------------------------------------'
    echo "Setting Environment Variables"
    echo '----------------------------------------------'
    
    # taken from https://raw.githubusercontent.com/thii/aws-codebuild-extras/master/install
    export CI=true
    export CODEBUILD=true
    export CODEBUILD_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
    export CODEBUILD_GIT_BRANCH="$(git symbolic-ref HEAD --short 2>/dev/null)"
    if [ "$CODEBUILD_GIT_BRANCH" = "" ] ; then
        CODEBUILD_GIT_BRANCH="$(git branch -a --contains HEAD | sed -n 2p | awk '{ printf $1 }')";
        export CODEBUILD_GIT_BRANCH=${CODEBUILD_GIT_BRANCH#remotes/origin/};
    fi
    export CODEBUILD_GIT_CLEAN_BRANCH="$(echo $CODEBUILD_GIT_BRANCH | tr '/' '.')"
    export CODEBUILD_GIT_ESCAPED_BRANCH="$(echo $CODEBUILD_GIT_CLEAN_BRANCH | sed -e 's/[]\/$*.^[]/\\\\&/g')"
    export CODEBUILD_GIT_MESSAGE="$(git log -1 --pretty=%B)"
    export CODEBUILD_GIT_AUTHOR="$(git log -1 --pretty=%an)"
    export CODEBUILD_GIT_AUTHOR_EMAIL="$(git log -1 --pretty=%ae)"
    export CODEBUILD_GIT_COMMIT="$(git log -1 --pretty=%H)"
    export CODEBUILD_GIT_SHORT_COMMIT="$(git log -1 --pretty=%h)"
    export CODEBUILD_GIT_TAG="$(git describe --tags --exact-match 2>/dev/null)"
    export CODEBUILD_GIT_MOST_RECENT_TAG="$(git describe --tags --abbrev=0)"
    export CODEBUILD_PULL_REQUEST=false
    if [ "${CODEBUILD_GIT_BRANCH#pr-}" != "$CODEBUILD_GIT_BRANCH" ] ; then
        export CODEBUILD_PULL_REQUEST=${CODEBUILD_GIT_BRANCH#pr-};
    fi
    export CODEBUILD_PROJECT=${CODEBUILD_BUILD_ID%:$CODEBUILD_LOG_PATH}
    export CODEBUILD_BUILD_URL=https://$AWS_DEFAULT_REGION.console.aws.amazon.com/codebuild/home?region=$AWS_DEFAULT_REGION#/builds/$CODEBUILD_BUILD_ID/view/new

    echo "==> AWS CodeBuild Extra Environment Variables:"
    echo "==> CI = $CI"
    echo "==> CODEBUILD = $CODEBUILD"
    echo "==> CODEBUILD_ACCOUNT_ID = $CODEBUILD_ACCOUNT_ID"
    echo "==> CODEBUILD_GIT_AUTHOR = $CODEBUILD_GIT_AUTHOR"
    echo "==> CODEBUILD_GIT_AUTHOR_EMAIL = $CODEBUILD_GIT_AUTHOR_EMAIL"
    echo "==> CODEBUILD_GIT_BRANCH = $CODEBUILD_GIT_BRANCH"
    echo "==> CODEBUILD_GIT_CLEAN_BRANCH = $CODEBUILD_GIT_CLEAN_BRANCH"
    echo "==> CODEBUILD_GIT_ESCAPED_BRANCH = $CODEBUILD_GIT_ESCAPED_BRANCH"
    echo "==> CODEBUILD_GIT_COMMIT = $CODEBUILD_GIT_COMMIT"
    echo "==> CODEBUILD_GIT_SHORT_COMMIT = $CODEBUILD_GIT_SHORT_COMMIT"
    echo "==> CODEBUILD_GIT_MESSAGE = $CODEBUILD_GIT_MESSAGE"
    echo "==> CODEBUILD_GIT_TAG = $CODEBUILD_GIT_TAG"
    echo "==> CODEBUILD_GIT_MOST_RECENT_TAG = $CODEBUILD_GIT_MOST_RECENT_TAG"
    echo "==> CODEBUILD_PROJECT = $CODEBUILD_PROJECT"
    echo "==> CODEBUILD_PULL_REQUEST = $CODEBUILD_PULL_REQUEST"

    echo 'Setting IMAGE_TAG_VERSION'
    set_tag_version

    # output env vars for debug
    print_env  
}

function get_ecr_image_by_tag() {
    aws ecr list-images --registry-id 895523100917 --repository-name ${1} | jq -r --arg TAGID "${2}" '.imageIds[] | select(.imageTag==$TAGID).imageDigest'
}

function get_dockerhub_image_by_tag() {
    curl -s https://hub.docker.com/v2/repositories/${1}/tags/${2} | jq -r '.images[0].digest'
}

function validate_image() {
  # does the tag exist
  echo '--------------------------------------------------------------------'
  echo "get ECR sha256 for repository-name '${IMAGE_NAME}' Tag '${IMAGE_TAG_VERSION}'"
  echo '--------------------------------------------------------------------'
  ecr_sha_tag=$(get_ecr_image_by_tag "${IMAGE_NAME}" "${IMAGE_TAG_VERSION}")
  echo "ecr_sha_tag:$ecr_sha_tag"

  # echo '--------------------------------------------------------------------'
  # echo "get docker hub sha256 for repository-name '"${PUBLIC_IMAGE}"' Tag '${IMAGE_TAG_VERSION}'"
  # echo '--------------------------------------------------------------------'
  # dockerhub_sha_tag=$(get_dockerhub_image_by_tag ""${PUBLIC_IMAGE}"" "${IMAGE_TAG_VERSION}")
  # echo "dockerhub_sha_tag:$dockerhub_sha_tag"

  # CONFIRM THE TAG sha256 IS THE SAME IN BOTH ECR AND DOCKER HUB REPOS
  # echo '--------------------------------------------------------------------'
  # echo "Check ECR sha256 is same as docker hub sha256 for repository-name '${PUBLIC_IMAGE}' Tag '${IMAGE_TAG_VERSION}' image"
  # echo '--------------------------------------------------------------------'
  # if [ "${ecr_sha_tag}" == "${dockerhub_sha_tag}" ]; then
  #     echo '------------------------------------------------------------------Success'
  #     echo 'ECR sha256 is same as docker hub sha256 for repository-name '${PUBLIC_IMAGE}' Tag '${IMAGE_TAG_VERSION}' image'
  #     echo '---------------------------------------------------------------------------'
  # else
  #     echo '***********************************************************************************ERROR'
  #     echo 'ECR sha256 is not the same as docker hub sha256 for repository-name '${PUBLIC_IMAGE}' Tag '${IMAGE_TAG_VERSION}' image'
  #     echo '****************************************************************************************'
  #     exit 1
  # fi

  # if branch is master, is tag sha256 same as latest sha256
  if [ "${CODEBUILD_GIT_BRANCH}" == "master" ]; then
      
      echo "Branch is ${CODEBUILD_GIT_BRANCH} so checking for sha256 for Tag '${IMAGE_TAG_VERSION}' is the same as sha256 for 'latest' tag for image"

      ecr_sha_latest=$(get_ecr_image_by_tag "${IMAGE_NAME}" 'latest')
      # dockerhub_sha_latest=$(get_dockerhub_image_by_tag "${PUBLIC_IMAGE}" 'latest')

      echo "ecr_sha_latest:$ecr_sha_latest"

      if [ "${ecr_sha_tag}" == "${ecr_sha_latest}" ]; then
          echo '---------------------------------------------------------------------------Success '
          echo 'AWS ECR sha256 is the same so we built and pushed both images correctly'
          echo '---------------------------------------------------------------------------'
      else
          echo '****************************************************************************************ERROR'
          echo 'AWS ECR sha256 is not the same so an error occurred building image or pushing an image correctly'
          echo '****************************************************************************************'
          exit 1
      fi 

      # echo "dockerhub_sha_latest:$dockerhub_sha_latest"

      # # if branch is master, is tag sha256 same as latest sha256
      # if [ "${dockerhub_sha_tag}" == "${dockerhub_sha_latest}" ]; then
      #     echo '---------------------------------------------------------------------------Success'
      #     echo 'Docker Hub sha256 is the same so we built and pushed both images correctly'
      #     echo '---------------------------------------------------------------------------'
      # else
      #     echo '****************************************************************************************ERROR'
      #     echo 'Docker Hub sha256 is not the same so an error occurred building image or pushing an image correctly'
      #     echo '****************************************************************************************'
      #     exit 1
      # fi 
  else 
      echo "Branch is ${CODEBUILD_GIT_BRANCH} so skipping check for current tag == latest"
  fi

}

# install pre-reqs
install_pre_reqs

# set environment
set_environment_variables

# login to ecr
ecr_login

# login to docker hub
docker_hub_login

#list current aws configuration
AWSCLI=$(which aws)
$AWSCLI configure list
$AWSCLI sts get-caller-identity

#build the image
build

#push the image to ECR and Docker Hub
push_image

# VALIDATE THE IMAGES WERE PUSHED TO THE ECR AND DOCKER HUB BY CONFIRMING THE IMAGE EXISTS FOR THE TAG IN BOTH REPOS
validate_image

exit 0