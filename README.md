# hmpps-delius-dss-offloc-docker

# Docker repo for Data Share System


Note: This replaces [hmpps-delius-dss-docker](https://github.com/ministryofjustice/hmpps-delius-dss-docker) repository which was owned by John Barber
  

### Purpose

Docker container used to download P-NOMIS DSS file and upload to delius. 

This container is executed under the AWS Batch Platform in the VPC we are updating the NDelius service with the DSS data.

### More Documentation

See the docs in [Confluence](https://dsdmoj.atlassian.net/wiki/spaces/DAM/pages/1488486513/Data+Share+System+DSS?search_id=e500873d-de55-4c49-9b77-dd5f6abfe714)
### Platforms

- delius-stage - Testing
- delius-prod  - Live

### Building the Dockerfile

- Currently the Dockerfile is built by Jenkins Job [Jenkins > Delius-Core > DSS/ > HMPPS DSS Docker Image Build](https://jenkins.engineering-dev.probation.hmpps.dsd.io/job/Delius-Core/job/DSS/job/HMPPS%20DSS%20Docker%20Image%20Build/)
- New AWS CodeBuild Project to build this image is at https://eu-west-2.console.aws.amazon.com/codesuite/codebuild/895523100917/projects/hmpps-delius-dss-offloc-docker/details?region=eu-west-2
  - task to create new Project https://jira.engineering-dev.probation.hmpps.dsd.io/browse/ALS-1788

### Deployment

Deployed using the https://github.com/ministryofjustice/hmpps-delius-core-terraform/tree/master/batch/dss folder via Terraform.

### Process

- Download credentials from SSM ParameterStore for this environment & update configs
- Starting File Transfer application.
  - Validating FileTransfer.properties configuration file...
  - Write temporary zip file.
  - Run OFFLOC file check for PNOMIS. (validation)
  - Attempting Auto Correct for validation errors
  - Start the FileImporter process (java)

### Logging

- Execution logs sent to the [/aws/batch/job](https://eu-west-2.console.aws.amazon.com/cloudwatch/home?region=eu-west-2#logsV2:log-groups/log-group/$252Faws$252Fbatch$252Fjob) Cloudwatch LogGroup in the specified account.
  
### Alarms

- Alarms sent to Slack channels depending upon if its prod/non-prod

| Account      | Slack Channel  (MOJ Digital & Technology) |
|--------------|--------------------------------------|
| delius-stage | #delius-alerts-deliuscore-nonprod    |
| delius-prod  | #delius-alerts-deliuscore-production |

### Testing

See [Testing.md](h./../Testing.md)


