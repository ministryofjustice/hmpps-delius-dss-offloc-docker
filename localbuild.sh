#!/bin/bash

export DSS_VERSION=3.0
export IMAGE_TAG_VERSION=0.0.0
export AWS_PROFILE=hmpps_eng
export REGISTRY=895523100917.dkr.ecr.eu-west-2.amazonaws.com

./buildimage.sh 'dss' dss_version=${DSS_VERSION} image_tag_version=${IMAGE_TAG_VERSION}