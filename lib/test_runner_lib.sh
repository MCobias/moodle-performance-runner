#!/bin/bash
#
# Helper functions for before run.

################################################
# Show usage of before run command.
#
################################################
function test_runner_usage() {
    cat << EOF
############################## Usage #############################################
#                                                                                #
# Usage: ./test_runner.sh -u users -l loops -r rampup -t throughput \            #
#                         -n run_group_name -d run_description      \            #
#                         [-p test_plan_file_path -s site_properties]            #
#                                                                                #
#   -n : The run group name, there will be comparision graphs by this group name #
#   -d : The run description, useful to identify the changes between runs.       #
#   -u : (optional) Force the number of users (threads)                          #
#   -l : (Optional) Force the number of loops                                    #
#   -r : (optional) Force the ramp-up period                                     #
#   -t : (optional) Force the throughput                                         #
#   -p : (optional) Path to testplan.jmx                                         #
#   -f : (Optional) Path to CSV files                                            #
#   -s : (optional) Path to site.properties (Needed when jmeter and              #
#        webserver is on different servers                                       #
#   -h : Help                                                                    #
#                                                                                #
##################################################################################
EOF
    exit 1
}

################################################
# Check if all params are passed prorerly.
# - expects -s and -t to be set.
#
################################################
function check_before_run_cmd {
    # Default is no verbose.
    VERBOSE=0

    while getopts 'hn:d:u:l:r:t:p:f:s' flag; do
      case "${flag}" in
        n) TESTPLAN_GROUP=' -Jgroup='"${OPTARG}" ;;
        d) TESTPLAN_DESC=' -Jdesc='"${OPTARG}" ;;
        u) TESTPLAN_USERS=' -Jusers='${OPTARG} ;;
        l) TESTPLAN_LOOP=' -Jloops='${OPTARG} ;;
        r) TESTPLAN_RAMPUP=' -Jrampup='${OPTARG} ;;
        t) TESTPLAN_THROUGHPUT=' -Jthroughput='${OPTARG} ;;
        p) TESTPLAN_JMX=${OPTARG} ;;
        f) TESTPLAN_CSV_PATH=' -Jcsvfilepath='${OPTARG} ;;
        s) TESTPLAN_SITE_DATA_FILE=${OPTARG} ;;
        h) test_runner_usage ;;
        ?) test_runner_usage ;;
      esac
    done

    # Ensure we have these set.
    if [[ -z $TESTPLAN_GROUP ]] || [[ -z $TESTPLAN_DESC ]]; then
        test_runner_usage
        exit 1
    fi

    if [[ ! -f ${TESTPLAN_JMX} ]]; then
        echo "Error: testplan.jmx file not found at $TESTPLAN_JMX" >&2
        test_runner_usage
        exit 1
    fi

    if [ ! -f ${TESTPLAN_SITE_DATA_FILE} ]; then
        echo "Error: The specified site data properties file does not exist." >&2
        test_runner_usage
        exit 1
    fi
}

load_properties "$PERFORMANCE_TOOL_DIRECTORY/config/jmeter_config.properties"