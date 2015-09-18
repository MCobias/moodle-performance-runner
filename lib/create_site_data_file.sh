#!/bin/bash
#
# Creates a site_data.properties file with the moodle/ site version data.
#
# Useful when using your own SQL dump and you can't use before_run_setup.sh
#
# Usage: cd /path/to/moodle-performance-runner && ./create_site_data_file.sh
#
# Arguments:
# No arguments
#
##############################################

# Exit on errors.
set -e

# Dependencies.
. ./lib.sh

# Checks the $cmds.
check_cmds

cd $PERFORMANCE_TOOL_DIRECTORY/moodle

# This should be enough.
save_moodle_site_data

# Returning home in case this script is called by others.
cd ..

outputinfo="
#######################################################################
Site info file created successfully

"

echo "$outputinfo"
exit 0
