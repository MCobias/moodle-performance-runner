#!/bin/bash
#
# Sets up a moodle site with courses and users and generates a JMeter test plan.
#
# Auto-backup feature only available for postgres and mysql, only available as interactive
# script when running other drivers.
#
# Usage: cd /path/to/moodle-performance-runner && /before_run_setup.sh -s SITESITE -t TESTPLANSIZE -v
#
# Arguments:
# * -s => Size of test data, one of the following options: XS, S, M, L, XL, XXL. More than 'M' is not recommended for development computers.
# * -t => Size of test plan, one of the following options: XS, S, M, L, XL, XXL. More than 'M' is not recommended for development computers.
# * -v (optional) verbose
#
##############################################

# Exit on errors.
set -e

PWD=`pwd`
CURRENT_FILE_DIRECTORY=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# Dependencies.
. $CURRENT_FILE_DIRECTORY/../lib/lib.sh
. $CURRENT_FILE_DIRECTORY/../lib/run_lib.sh

# Check if command params are correctly passed.
check_before_run_cmd $@

# Hardcoded values.
readonly SITE_FULL_NAME="Performance test site"
readonly SITE_SHORT_NAME="Performance test site"
readonly SITE_ADMIN_USERNAME="admin"
readonly SITE_ADMIN_PASSWORD="admin"
readonly FILE_NAME_USERS="$PERFORMANCE_TOOL_DIRECTORY/moodle_testplan_data/"
readonly FILE_NAME_TEST_PLAN="$PERFORMANCE_TOOL_DIRECTORY/jmeter_data/moodle_testplan_data/testplan.jmx"

# Checks the $cmds.
check_cmds

# Creating & cleaning dirroot & dataroot (keeping .git)
clean_create_dir_structure

# Download behat-generator and behat-2jmx via composer.
download_composer_dependencies

# Move to moodle dirroot and begin setting up everything.
cd $PERFORMANCE_TOOL_DIRECTORY/moodle

echo "### Checking out $repository ($basecommit)"
checkout_branch $repository 'origin' $basecommit

# Initialize moodle for installation. Write config.php using webserver_conf.properties.
init_moodle

# Install and generate moodle site for base commit. If not installed earlier.
echo "#######################################################################"
# Install site.
echo "### Installing base site"
install_site

# Generate site data.
echo "### Generating site data"
generate_site_data

# Generate test plan.
echo "### Generating test plan"
generate_testplan

# Compress and keep a copy in jmeter_data/moodle_testplan_data, so it can be downloaded by external system.
save_testplan_files

cd $PERFORMANCE_TOOL_DIRECTORY/moodle
# Upgrading moodle, although we are not sure that base and before branch are different.
echo "### Upgrading Moodle ($basecommit) to $beforebranch"
checkout_branch $beforebranchrepository 'before' $beforebranch

${phpcmd} admin/cli/upgrade.php \
    --non-interactive \
    --allow-unstable \
    > /dev/null || \
    throw_error "Moodle can not be upgraded to $beforebranch"

# Stores the site data in an jmeter-accessible file.
save_moodle_site_information

# Returning to the script dir.
cd $PWD

# Also output the info.
outputinfo="
#######################################################################
'Before' run setup finished successfully.

Note the following files were generated, you will need this info when running
testrunner.sh in a different server, they are also saved in test_files.properties.
- Files used by test plan:
$FILE_NAMES_TEST_PLAN

Now you can:
- Change the site configuration
- Change the cache stores
And to continue with the test you should:
- Run restart_services.sh (or manually restart web and database servers if
  this script doesn\'t suit your system)
- Run test_runner.sh
"
echo "$outputinfo"

exit 0
