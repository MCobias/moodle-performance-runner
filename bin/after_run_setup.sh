#!/bin/bash
#
# Prepares the next test run after finished running the before_run_setup.sh script.
# * Restores database
# * Restores dataroot
# * Upgrades moodle if necessary
#
# Auto-restore feature only available for postgres and mysql.
#
# Usage: cd /path/to/moodle-performance-tool && bin/after_run_setup.sh
#
# No arguments
#
##############################################

# Exit on errors.
set -e

PWD=`pwd`
CURRENT_FILE_DIRECTORY=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
CURRENT_PLAN_PROP_FILE=${CURRENT_FILE_DIRECTORY}'/../jmeter_data/moodle_testplan_data/currenttestplan.prop'

# Dependencies.
. ${CURRENT_FILE_DIRECTORY}'/../lib/lib.sh'
. ${CURRENT_FILE_DIRECTORY}'/../lib/run_lib.sh'

# We need the paths.
if [ ! -z "$1" ]; then
    output="Usage: `basename $0`

Prepares the next test run after finished running the before_run_setup.sh script.
* Restores database
* Restores dataroot
* Upgrades moodle if necessary
"
    echo "$output" >&2
    exit 1
fi

# Checking as much as we can that before_run_setup.sh was
# already executed and finished successfully.
errormsg="Error: Did you run before_run_test.sh before running this one? "
if [ ! -e $CURRENT_PLAN_PROP_FILE ]; then
    echo $errormsg >&2
    exit 1
fi
if [ ! -d ${CURRENT_FILE_DIRECTORY}"/../moodle" ]; then
    echo $errormsg >&2
    exit 1
fi
if [ ! -d ${CURRENT_FILE_DIRECTORY}"/../moodle/.git" ]; then
    echo $errormsg >&2
    exit 1
fi

# Checks the $cmds.
check_cmds

# Get generated test plan values.
load_properties $CURRENT_PLAN_PROP_FILE

# Move to moodle dirroot and begin setting up everything.
cd $PERFORMANCE_TOOL_DIRECTORY/moodle

echo "### Checking out $repository ($basecommit)"
checkout_branch $repository 'origin' $basecommit

# Remove current dataroot and restore the provided one (Better using chown...).
echo "Restoring Site ${basecommit} with data ${dataplansize}"
cd $CURRENT_FILE_DIRECTORY
vendor/bin/moodle_behat_generator --restore=site_${installedsitebasecommit}_${dataplansize}_${dataplanversion} > /dev/null 2>&1 || \
    throw_error "Before run was not executed, site state site_${installedsitebasecommit}_${dataplansize}_${dataplanversion} doesn't exist."

# Upgrading moodle, although we are not sure that before and after branches are different.
echo "Upgrading Moodle ($basecommit) to $afterbranch"
checkout_branch $afterbranchrepository 'after' $afterbranch
${phpcmd} admin/cli/upgrade.php --non-interactive --allow-unstable > /dev/null || \
    throw_error "Moodle can not be upgraded to $afterbranch"

# Stores the site data in an jmeter-accessible file.
save_moodle_site_information

# Info, all went as expected and we are all happy.
outputinfo="
#######################################################################
'After' run setup finished successfully.

Now you can:
- Change the site configuration
- Change the cache stores
And to continue with the test you should:
- Run restart_services.sh (or manually restart web and database servers
  if this script doesn\'t suit your system)
- Run test_runner.sh
"

echo "$outputinfo"
exit 0
