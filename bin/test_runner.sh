#!/bin/bash
#
# Script to run the test plan using jmeter
#
# Runs will be grouped according to $1 so they
# can be compared easily. The run description
# will be useful to identify them.
#
# Usage:
#   cd /path/to/moodle-performance-runner
#   ./test_runner.sh [OPTIONS] {run_group_name} {run_description} {test_plan_file_path} {users_file_path}
#
# Arguments:
# * $1 => The run group name, there will be comparision graphs by this group name
# * $2 => The run description, useful to identify the changes between runs.
# * $3 => The test plan file path
# * $4 => The path to the file with user's login data
# * $5 => The path to the file with the tested site data
#
# Options:
# * -u => Force the number of users (threads)
# * -l => Force the number of loops
# * -r => Force the ramp-up period
# * -t => Force the throughput
#
##############################################

# Exit on errors.
set -e

PWD=`pwd`
CURRENT_FILE_DIRECTORY=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
LOGS_DIR=${CURRENT_FILE_DIRECTORY}'/../jmeter_data'

# Dependencies.
. $CURRENT_FILE_DIRECTORY/../lib/lib.sh
. $CURRENT_FILE_DIRECTORY/../lib/test_runner_lib.sh

# Defaults when jmeter is running in the same server than the web server.
# These will be updated if passed as option to this script.
if [[ -z ${testplandataroot} ]]; then
    TESTPLAN_JMX=${CURRENT_FILE_DIRECTORY}'/../jmeter_data/moodle_testplan_data/testplan.jmx'
else
    TESTPLAN_JMX=${testplandataroot}/testplan.jmx
fi
TESTPLAN_SITE_DATA_FILE=${CURRENT_FILE_DIRECTORY}'/../moodle/site_data.properties'

# Check if command params are correctly passed.
check_before_run_cmd $@

# Load the site data.
load_properties $TESTPLAN_SITE_DATA_FILE

# Creating the results cache directory for images.
if [ ! -d ${CURRENT_FILE_DIRECTORY}'/../cache' ]; then
    mkdir -m 777 ${CURRENT_FILE_DIRECTORY}'/../cache'
else
    chmod 777 ${CURRENT_FILE_DIRECTORY}'/../cache'
fi

# Uses the test plan specified in the CLI call.
datestring=`date '+%Y%m%d%H%M'`
TESTPLAN_LOG_FILE=${LOGS_DIR}'/logs/jmeter.'${datestring}'.log'
TESTPLAN_RUN_OUTPUT=${LOGS_DIR}'/runs_outputs/'${datestring}'.output'

# Include logs string.
TESTPLAN_INCLUDE_LOGS=' -Jincludelogs='${includelogs}

# Fix jmeter_data pathin recorder.bsf and recorderfunctions.bsf
# This is commented for now, as we should not be changing the actual code.
# Best way is to run the jmeter command from the root and all related paths will be sorted.
#sed -i -e 's@".*jmeter_data/@"'${LOGS_DIR}'/@g' ${CURRENT_FILE_DIRECTORY}/../lib/recorderfunctions.bsf
#sed -i -e 's@ ".*jmeter_data/@ "'${LOGS_DIR}'/@g' ${CURRENT_FILE_DIRECTORY}/../lib/recorder.bsf
# Always run jmeter from performance main dir.
cd $CURRENT_FILE_DIRECTORY/..

# Run it baby! (without GUI).
echo "#######################################################################"
echo "Test running... (time for a coffee?)"

jmetererrormsg="Jmeter can not run, ensure that:
* The test plan and the users files are ok
* You provide correct arguments to the script"

jmeterbin=${jmeter_path%}/bin/jmeter
$jmeterbin \
    -n \
    -j $TESTPLAN_LOG_FILE \
    -t $TESTPLAN_JMX \
    $TESTPLAN_CSV_PATH \
    $TESTPLAN_GROUP \
    $TESTPLAN_DESC \
    -Jsiteversion="$siteversion" \
    -Jsitebranch="$sitebranch" \
    -Jsitecommit="$sitecommit" \
    $TESTPLAN_INCLUDE_LOGS \
    $TESTPLAN_USERS \
    $TESTPLAN_LOOP \
    $TESTPLAN_RAMPUP \
    $TESTPLAN_THROUGHPUT \
    > $TESTPLAN_RUN_OUTPUT || \
    throw_error $jmetererrormsg

# Log file correctly generated.
if [ ! -f $TESTPLAN_LOG_FILE ]; then
  echo "Error: JMeter has not generated any log file in $TESTPLAN_LOG_FILE"
  exit 1
fi

# Grep the logs looking for errors and warnings.
for errorkey in ERROR WARN; do

  # Also checking that the errorkey is the log entry type.
  if grep $errorkey $TESTPLAN_LOG_FILE | awk '{print $3}' | grep -q $errorkey ; then

    echo "Error: \"$errorkey\" found in jmeter logs, read $TESTPLAN_LOG_FILE \
to see the full trace. If you think that this is a false failure report the \
issue in https://github.com/moodlehq/moodle-performance-runner/issues."
    exit 1
  fi
done

outputinfo="
#######################################################################
Test plan completed successfully.

To compare this run with others remember to execute after_run_setup.sh before
it to clean the site restoring the database and the dataroot.
"
echo "$outputinfo"

cd $PWD
exit 0
