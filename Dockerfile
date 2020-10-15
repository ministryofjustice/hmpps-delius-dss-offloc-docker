FROM mojdigitalstudio/hmpps-base-java:latest
# Build time variables
ARG DSS_VERSION
ENV DSS_VERSION=$DSS_VERSION

# AWS Creds to override IAM Role for local testing
ARG AWS_ACCESS_KEY_ID
ENV AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
ARG AWS_SECRET_ACCESS_KEY
ENV AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
ARG AWS_SESSION_TOKEN
ENV AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN

# Run time variables
ENV DSS_DSSWEBSERVERURL=$DSS_DSSWEBSERVERURL
ENV DSS_HMPSSERVERURL=$DSS_HMPSSERVERURL
ENV DSS_PNOMISFILEEXTENSION=$DSS_PNOMISFILEEXTENSION
ENV DSS_FILEIMPORTERSTARTUPCMD=$DSS_FILEIMPORTERSTARTUPCMD
ENV DSS_TESTINGAUTOCORRECT=$DSS_TESTINGAUTOCORRECT
ENV DSS_TESTMODE=$DSS_TESTMODE
ENV DSS_TESTFILE=$DSS_TESTFILE
ENV DSS_PROJECT=$$DSS_PROJECT
ENV DSS_AWSREGION=$DSS_AWSREGION


# Elevate for package install
USER root
COPY config /dss_config
COPY scripts/ /dss_scripts

RUN apk -v --no-cache --update add \
        xmlstarlet \
        && \
    rm /var/cache/apk/* && \
    mkdir /dss /dss_artefacts && \
    chown -R tools:tools /dss* && \
    chmod -R 0700 /dss*
# Switch back to unpril'd user
USER tools

COPY ./NDelius-DSS-EncryptionUtility-$DSS_VERSION-EU.zip /dss_artefacts/NDelius-DSS-EncryptionUtility-$DSS_VERSION-EU.zip
COPY ./NDelius-DSS-FileTransfer-$DSS_VERSION-FT.zip /dss_artefacts/NDelius-DSS-FileTransfer-$DSS_VERSION-FT.zip
COPY ./test_file.zip /dss_artefacts/test_file.zip
# TODO Workaround for FileImporter not following redirects issue
COPY ./NDelius-DSS-FileImporter-3.0-FI.zip /dss_artefacts/NDelius-DSS-FileImporter-$DSS_VERSION-FI.zip

RUN /dss_scripts/dss_setup.sh

CMD ["/dss_scripts/dss_run.sh"]

