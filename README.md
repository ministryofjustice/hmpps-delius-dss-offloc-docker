# hmpps-delius-dss-offloc-docker

Docker repo for Data Share System


Note: This replaces hmpps-delius-dss-docker repository which was owned by John Barber
  

## Purpose

Build, test and push a docker container which when run will invoke a single run of the DSS batch process

Default DSS Config can be overridden by specifying environment variables at runtime,
e.g. `docker run -e DSS_ENVIRONMENT=delius-prod -e DSS_TESTMODE=true -e DSS_DSSWEBSERVERURL=https://server.local:8080 <image>`

The table below lists the available variables:

| Variable Name | Type | Purpose |
|--|--|--|
| DSS_ENVIRONMENT | String, e.g. delius-core-sandpit | nDelius AWS Environment |
| DSS_PROJECT | String, e.g. delius | nDelius Project Name |
| DSS_AWSREGION | String, e.g. eu-west-2 | nDelius AWS Environment Region |
| DSS_DSSWEBSERVERURL | String (URL), e.g. https://interface.test.delius.probation.hmpps.dsd.io/NDeliusDSS  | nDelius API Endpoint |
| DSS_HMPSSERVERURL | String (URL), e.g. https://ped.hmps.gsi.gov.uk  | P-NOMIS Endpoint |
| DSS_PNOMISFILEEXTENSION | String (File Extension), e.g. .dat | Unzipped file extension for source offloc file  |
| DSS_FILEIMPORTERSTARTUPCMD | String  | The operating system command that should be used to invoke the File Importer application.  |
| DSS_TESTINGAUTOCORRECT | BOOLEAN | Attempt to auto correct files |
| DSS_TESTMODE | BOOLEAN | Specifies whether or not the File Transfer application should run in test mode. (i.e. read OFFLOC file from the local file system)  |
| DSS_TESTFILE | String (Filesystem Path), e.g. /dss/testfile.zip | Path to an OFFLOC file that should be used in a test environment. |
| DSS_BUILDTESTMODE | Any | If set, signifies a test run as part of the Docker build pipeline and won't run DSS tasks |
