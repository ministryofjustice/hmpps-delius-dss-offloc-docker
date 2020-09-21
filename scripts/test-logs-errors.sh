#!/bin/bash


function err_exit {
    echo "$ERROR_FLAG Task $1 exited with code $2";
    exit $2;
}

function check_log_errors {
    
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

FTRESULT=0

echo "FT Result == $FTRESULT"
if [ $FTRESULT -eq 0 ]; then
    echo "Checking logs for errors..."
    # check_log_errors ./filetransfer.log
    check_log_errors ./dss-log.csv
else
    err_exit FileTransfer $FTRESULT
fi