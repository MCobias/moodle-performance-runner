#!/bin/bash
#
# Helper functions for before run.

################################################
# Show usage of before run command.
#
################################################
function before_run_usage() {
    cat << EOF
############################## Usage ###################################
#                                                                      #
# Usage: ./before_run_setup.sh -s SITESITE -t TESTPLANSIZE -v          #
#   -s : Size of data generated for size (XS, S, M, L, XL, XXL)        #
#   -t : Test plan size (XS, S, M, L, XL, XXL)                         #
#   -v : (optional) Verbose                                            #
#   -f : (optional) force clean all previous setup and start fresh     #
#   -h : Help                                                          #
#                                                                      #
########################################################################
EOF
    exit 1
}

################################################
# Check if all params are passed prorerly.
# - expects -s and -t to be set.
#
################################################
function check_before_run_cmd() {
    # Default is no verbose.
    VERBOSE=0

    while getopts 'hfs:t:v' flag; do
      case "${flag}" in
        h) before_run_usage ;;
        v) VERBOSE=1 ;;
        s) SITESIZE=$OPTARG ;;
        t) TESTPLANSIZE=$OPTARG ;;
        f) FORCECLEAN=1 ;;
        ?) before_run_usage ;;
      esac
    done

    # Ensure we have these set.
    if [[ -z $SITESIZE ]] || [[ -z $TESTPLANSIZE ]]; then
        before_run_usage
        exit 1
    fi

    # Ensure SITESIZE and TESTPLANSIZE have correct value. (XS, S, M, L, XL, XXL)
    if [ "$SITESIZE" != "XS" ] && [ "$SITESIZE" != "S" ] && [ "$SITESIZE" != "M" ] && [ "$SITESIZE" != "L" ]\
        && [ "$SITESIZE" != "XL" ] && [ "$SITESIZE" != "XXL" ]; then
        before_run_usage
        exit 1
    fi

    if [ "$TESTPLANSIZE" != "XS" ] && [ "$TESTPLANSIZE" != "S" ] && [ "$TESTPLANSIZE" != "M" ] && [ "$TESTPLANSIZE" != "L" ]\
        && [ "$TESTPLANSIZE" != "XL" ] && [ "$TESTPLANSIZE" != "XXL" ]; then
        before_run_usage
        exit 1
    fi
}

################################################
# Downloads composer dependencies.
################################################
download_composer_dependencies() {
    # Move to tool directory.
    cd $PERFORMANCE_TOOL_DIRECTORY

    # Install composer dependencies.
    if [ ! -f "composer.phar" ]; then
        ${curlcmd} -sS https://getcomposer.org/installer | php > /dev/null || \
            throw_error "composer.phar is not downloaded"

        php composer.phar install > /dev/null || \
            throw_error "composer dependencies not installed."
    # else
        # TODO: Add composer.lock and change it to install.
        # php composer.phar update > /dev/null || \
        #    throw_error "composer dependencies not updated."
    fi
}

################################################
# Creates config.php in moodle directory.
################################################
init_moodle() {
    # Move to moodle dirroot and begin setting up everything.
    cd $PERFORMANCE_TOOL_DIRECTORY/moodle

    # Copy config.php template and set user properties.
    replacements="%%dbtype%%#$dbtype
    %%dbhost%%#$dbhost
    %%dbname%%#$dbname
    %%dbuser%%#$dbuser
    %%dbpass%%#$dbpass
    %%dbprefix%%#$dbprefix
    %%wwwroot%%#$wwwroot
    %%dataroot%%#$dataroot
    %%perfdataroot%%#$perfdataroot
    %%testplandataroot%%#$testplandataroot"

    configfilecontents="$( cat $PERFORMANCE_TOOL_DIRECTORY/config/config.php.template )"
    for i in ${replacements}; do
        configfilecontents=$( echo "${configfilecontents}" | sed "s#${i}#g" )
    done

    # Overwrites the previous config.php file.
    errorstr="Moodle's config.php can not be written, \
    check $PERFORMANCE_TOOL_DIRECTORY/moodle directory \
    (and $PERFORMANCE_TOOL_DIRECTORY/moodle/config.php if it exists) permissions."

    echo "${configfilecontents}" > config.php || \
        throw_error "$errorstr"
    chmod $PERMISSIONS config.php

    # Install composer dependencies.
    if [ ! -f "composer.phar" ]; then
        ${curlcmd} -sS https://getcomposer.org/installer | php > /dev/null || \
                throw_error "composer.phar is not downloaded"
    fi

    if [ -d "vendor" ]; then
        rm -r vendor
    fi

    moodle_print "### Installing composer dependencies"
    ${phpcmd} composer.phar install > /dev/null 2>&1 || \
        throw_error "composer dependencies not installed."

    cd $PERFORMANCE_TOOL_DIRECTORY
}

################################################
# Delete old dir and creats new.
################################################
function clean_create_dir_structure {
    if [ ! -e "$dataroot" ]; then
        mkdir -m $PERMISSIONS $dataroot || \
            throw_error "There was a problem creating $dataroot directory"
    else
        # If it already existed we clean it
        delete_files "$dataroot/*"
    fi

    # Create moodle dir. if not present.
    if [ ! -e ${PERFORMANCE_TOOL_DIRECTORY}'/moodle' ]; then
        mkdir -m $PERMISSIONS ${PERFORMANCE_TOOL_DIRECTORY}'/moodle' || \
            throw_error "There was a problem creating moodle/ directory"
    fi
}

################################################
# Install moodle site for the base commit, if
# it's not generated before.
################################################
function install_site {

    local INSTALL=1

    cd $PERFORMANCE_TOOL_DIRECTORY
    # Check if we already have installed site for this basecommit.
    # As we take backup for initial install for every commit, so check if that backup exists.
    if [[ -f $perfdataroot/sitegenerator/init_${basecommit}.zip ]]; then
            INSTALL=0
    else
        # Drop site if it already installed.
        vendor/bin/moodle_behat_generator --dropsite --moodlepath ${PERFORMANCE_TOOL_DIRECTORY}'/moodle' --datapath=${perfdataroot}
        INSTALL=1
    fi

    if [[ "$INSTALL" == "1" ]]; then
        echo "Installing Moodle ($basecommit)"
        if [[ "$VERBOSE" == "0" ]]; then
            vendor/bin/moodle_behat_generator -i --moodlepath=${PERFORMANCE_TOOL_DIRECTORY}'/moodle' --datapath=${perfdataroot} > /dev/null 2>&1 || \
                exit 1
        else
            vendor/bin/moodle_behat_generator -i --moodlepath=${PERFORMANCE_TOOL_DIRECTORY}'/moodle' --datapath=${perfdataroot} || \
                exit 1
        fi


        # Back up data to be used later.
        if [[ "$VERBOSE" == "0" ]]; then
            vendor/bin/moodle_behat_generator --backup=init_${basecommit} > /dev/null 2>&1 || \
                throw_error "The test site is not installed."
        else
            vendor/bin/moodle_behat_generator --backup=init_${basecommit} || \
                throw_error "The test site is not installed."
        fi
        echo "installedsitebasecommit=$basecommit" > $PERFORMANCE_TOOL_DIRECTORY/jmeter_data/moodle_testplan_data/currenttestplan.prop
    else
        moodle_print "Base site already installed ($basecommit), skipping installation..."
    fi
}

################################################
# Generate site data
################################################
function generate_site_data {

    # Change to moodle dir.
    local dir=`pwd`
    local GENERATEDATA=1
    local RESTOREINIT=1

    cd $PERFORMANCE_TOOL_DIRECTORY/moodle

    # This function expects the site is installed for the basecommit.
    # Exit if it's not installed.
    if [[ ! -f $perfdataroot/sitegenerator/init_${basecommit}.zip ]]; then
        echo "There is no site installed for base commit: ${basecommit}"
        exit 1
    fi

    cd $PERFORMANCE_TOOL_DIRECTORY
    DATA_PLAN_VERSION=$(vendor/bin/moodle_behat_generator --value=version --moodlepath=${PERFORMANCE_TOOL_DIRECTORY}'/moodle' --datapath=${perfdataroot})
    cd $PERFORMANCE_TOOL_DIRECTORY/moodle

    # Following site state should be either created or exists.
    local sitestate='site_'${basecommit}'_'${SITESIZE}'_'${DATA_PLAN_VERSION}

    # Check if site has been generated for the specified size and base commit.
    if [[ -f $perfdataroot/sitegenerator/${sitestate}.zip ]]; then
        GENERATEDATA=0
    fi

    if [[ ! -z $FORCECLEAN ]]; then
        delete_files $PERFORMANCE_TOOL_DIRECTORY/jmeter_data/moodle_testplan_data/currenttestplan.prop
        GENERATEDATA=1
    fi

    if [[ "$GENERATEDATA" == "1" ]]; then
        if [[ -f $PERFORMANCE_TOOL_DIRECTORY/jmeter_data/moodle_testplan_data/currenttestplan.prop ]]; then
            . $PERFORMANCE_TOOL_DIRECTORY/jmeter_data/moodle_testplan_data/currenttestplan.prop

            # If sitesize and base commits are same then no need to do anything.
            if [[ "$installedsitebasecommit" == "$basecommit" ]]; then
                RESTOREINIT=0
            fi
        fi

        cd $PERFORMANCE_TOOL_DIRECTORY
        # Restore init site
        if [[ "$RESTOREINIT" -eq 1 ]]; then
            vendor/bin/moodle_behat_generator --restore=init_${basecommit} > /dev/null 2>&1 || \
                throw_error "The test site is not installed."
        fi

        # Generate data for the specified site size.
        if [[ "$VERBOSE" == "0" ]]; then
            vendor/bin/moodle_behat_generator -d $SITESIZE > /dev/null 2>&1 || \
                exit 1
        else
            vendor/bin/moodle_behat_generator -d $SITESIZE || \
                exit 1
        fi

        # Back up data to be used later.
        if [[ "$VERBOSE" == "0" ]]; then
            vendor/bin/moodle_behat_generator --backup=${sitestate} > /dev/null 2>&1 || \
                throw_error "Error backing up data generated site."
        else
            vendor/bin/moodle_behat_generator --backup=${sitestate}  || \
                throw_error "Error backing up data generated site."
        fi
        # Re-write the prop file.
        echo "installedsitebasecommit=$basecommit" > $PERFORMANCE_TOOL_DIRECTORY/jmeter_data/moodle_testplan_data/currenttestplan.prop
        echo "dataplansize=$SITESIZE" >> $PERFORMANCE_TOOL_DIRECTORY/jmeter_data/moodle_testplan_data/currenttestplan.prop
        echo "dataplanversion=$DATA_PLAN_VERSION" >> $PERFORMANCE_TOOL_DIRECTORY/jmeter_data/moodle_testplan_data/currenttestplan.prop
    else
        moodle_print "No need to generate data. It's already generated."
    fi

    cd $dir
}

function browsermob_selenium {
    if [ -z "$1" ]; then
      echo "browsermob_selenium {start|stop}"
      exit
    fi

    case "$1" in
    start)
        # Run browsermob proxy
        if [[ "$browsermobproxypath" == "" ]]; then
            echo "Set browsermobproxypath in webserver_config.properties"
            exit 1
        fi
        ${browsermobproxypath} -port 9090 --use-littleproxy true &> /dev/null &
        sleep 10

        # Run selenium.
        if [[ "$seleniumjarpath" == "" ]]; then
            echo "Set seleniumjarpath in webserver_config.properties"
            exit 1
        fi
        java -jar ${seleniumjarpath} &> /dev/null &
        sleep 5
    ;;
    stop)
        # Stop selenium.
        pid=$( ps -ef | grep selenium | grep -v grep | awk '{print $2}' )
        if [ ! -z "$pid" ]; then
            kill $pid &> /dev/null &
        fi

        # Stop browsermobproxy.
        pid=$( ps -ef | grep browsermob | grep -v grep | awk '{print $2}' )
        if [ ! -z "$pid" ]; then
            kill $pid &> /dev/null &
        fi
        sleep 5
    ;;
    esac
}

################################################
# Generate test plan.
################################################
function generate_testplan {

    cd ${PERFORMANCE_TOOL_DIRECTORY}
    # Get testplan and dataplan versions first.
    TEST_PLAN_VERSION=$(vendor/bin/moodle_behat_2jmx --value=version --moodlepath=${PERFORMANCE_TOOL_DIRECTORY}'/moodle' --datapath=${perfdataroot})
    DATA_PLAN_VERSION=$(vendor/bin/moodle_behat_generator --value=version --moodlepath=${PERFORMANCE_TOOL_DIRECTORY}'/moodle' --datapath=${perfdataroot})

    # This function expects the site is installed for the basecommit, with specified size.
    # Exit if it's not installed.
    if [[ ! -f $perfdataroot/sitegenerator/site_${basecommit}_${SITESIZE}_${DATA_PLAN_VERSION}.zip ]]; then
        echo "There is no site installed for base commit: ${basecommit} with size: ${SITESIZE}"
        exit 1
    fi

    if [[ -f $PERFORMANCE_TOOL_DIRECTORY/jmeter_data/moodle_testplan_data/currenttestplan.prop ]]; then
        . $PERFORMANCE_TOOL_DIRECTORY/jmeter_data/moodle_testplan_data/currenttestplan.prop

        # If sitesize and base commits are same then no need to do anything.
        if [ "$dataplansize" == "$SITESIZE" ] && [ "$installedsitebasecommit" == "$basecommit" ]  \
            && [ "$testplansize" == "$TESTPLANSIZE" ] && [ "$DATA_PLAN_VERSION" == "$dataplanversion" ] \
            && [ "$TEST_PLAN_VERSION" == "$testplanversion" ]; then
            GENEREATE=0
        else
            GENEREATE=1
        fi
    else
        GENEREATE=1
    fi

    # Change to moodle dir.
    if [[ "$GENEREATE" == "1" ]] || [[ ! -z $FORCECLEAN ]]; then
        local dir=`pwd`
        local RESTOREDATASITE=1

        echo "Generating test plan"
        cd $PERFORMANCE_TOOL_DIRECTORY/moodle

        # Start browsermob and selenium
        moodle_print "Starting browsermob proxy and selenium"
        browsermob_selenium stop
        sleep 2
        browsermob_selenium start

        # Restore data site.
        if [[ -f $PERFORMANCE_TOOL_DIRECTORY/jmeter_data/moodle_testplan_data/currenttestplan.prop ]]; then
            . $PERFORMANCE_TOOL_DIRECTORY/jmeter_data/moodle_testplan_data/currenttestplan.prop

            # If sitesize and base commits are same then no need to do anything.
            if [ "$dataplansize" == "$SITESIZE" ] && [ "$installedsitebasecommit" == "$basecommit" ] \
                && [ "$DATA_PLAN_VERSION" == "$dataplanversion" ]; then
                RESTOREDATASITE=0
            else
                RESTOREDATASITE=1
            fi
        else
            RESTOREDATASITE=1
        fi

        cd $PERFORMANCE_TOOL_DIRECTORY
        if [[ "$RESTOREDATASITE" -eq 1 ]]; then
            moodle_print "Restoring Site ${basecommit} with data ${SITESIZE}"
            vendor/bin/moodle_behat_generator --restore=site_${basecommit}_${SITESIZE}_${DATA_PLAN_VERSION} > /dev/null 2>&1 || \
                throw_error "The test site is not installed."
        fi

        moodle_print "Generating testplan for ${basecommit}, size ${TESTPLANSIZE}"
        if [[ "$VERBOSE" == "0" ]]; then
            vendor/bin/moodle_behat_2jmx -t=${TESTPLANSIZE} --proxyurl localhost:9090 --proxyport 8081 --force --moodlepath=${PERFORMANCE_TOOL_DIRECTORY}'/moodle' --datapath=${perfdataroot} > /dev/null 2>&1 || \
                exit 1
        else
            vendor/bin/moodle_behat_2jmx -t=${TESTPLANSIZE} --proxyurl localhost:9090 --proxyport 8081 --force --moodlepath=${PERFORMANCE_TOOL_DIRECTORY}'/moodle' --datapath=${perfdataroot} || \
                exit 1
        fi

        # Save information about the current test plan.
        echo "installedsitebasecommit=$basecommit" > $PERFORMANCE_TOOL_DIRECTORY/jmeter_data/moodle_testplan_data/currenttestplan.prop
        echo "dataplansize=$SITESIZE" >> $PERFORMANCE_TOOL_DIRECTORY/jmeter_data/moodle_testplan_data/currenttestplan.prop
        echo "dataplanversion=$DATA_PLAN_VERSION" >> $PERFORMANCE_TOOL_DIRECTORY/jmeter_data/moodle_testplan_data/currenttestplan.prop
        echo "testplansize=$TESTPLANSIZE" >> $PERFORMANCE_TOOL_DIRECTORY/jmeter_data/moodle_testplan_data/currenttestplan.prop
        echo "testplanversion=$TEST_PLAN_VERSION" >> $PERFORMANCE_TOOL_DIRECTORY/jmeter_data/moodle_testplan_data/currenttestplan.prop

        # Stop browsermob and selenium
        moodle_print "Stopping browsermob proxy"
        browsermob_selenium stop

        cd $dir
    else
        moodle_print "Test plan already exists."
    fi
}

################################################
# Creates a file with data about the site.
#
# Requires scripts to move to moodle/ before
# calling it and returning to root if necessary.
#
################################################
function save_moodle_site_information {
    # Change to moodle dir.
    local dir=`pwd`
    cd $PERFORMANCE_TOOL_DIRECTORY/moodle

    # We should already be in moodle/.
    if [ ! -f "version.php" ]; then
        echo "Error: save_moodle_site_information() should only be called after cd to moodle/" >&2
        exit 1
    fi

    # Getting the current site data.
    local siteversion="$(cat version.php | \
        grep '$version' | \
        grep -o '[0-9]\+.[0-9]\+' | \
        head -n 1)"
    local sitebranch="$(cat version.php | \
        grep '$branch' | \
        grep -o '[0-9]\+' | \
        head -n 1)"
    local sitecommit="$(${gitcmd} show --oneline | \
        head -n 1 | \
        sed 's/\"/\\"/g')"

    local sitedatacontents="siteversion=\"$siteversion\"
sitebranch=\"$sitebranch\"
sitecommit=\"$sitecommit\""

    echo "${sitedatacontents}" > site_data.properties || \
        throw_error "Site data properties file can not be written, check $currentwd/moodle directory permissions."
    cd $dir
}

################################################
# Saves testplan files in tar file to
# $perfdataroot/testplangenerator/moodle_testplan/
# So it can be downloaded by remote jmeter server.
#
# Also, saves files in the defined path, where all
# testplan files will be accessed.
#
################################################
function save_testplan_files {
    local dir=`pwd`
    cd $perfdataroot/testplangenerator/moodle_testplan/
    tar -cvzf $PERFORMANCE_TOOL_DIRECTORY/jmeter_data/moodle_testplan_data/moodle_testplan.tar.gz * > /dev/null 2>&1

    if [[ -z ${testplandataroot} ]]; then
        testplandataroottouse=${CURRENT_FILE_DIRECTORY}'/../jmeter_data/moodle_testplan_data'
    else
        testplandataroottouse=${testplandataroot}
    fi
    # Untar all files in the testplan, as expected by the plan.
    if [[ -d $testplandataroottouse ]]; then
        mkdir -p $testplandataroottouse
    fi
    cd $testplandataroottouse
    FILE_NAMES_TEST_PLAN=$(tar -xvzf $PERFORMANCE_TOOL_DIRECTORY/jmeter_data/moodle_testplan_data/moodle_testplan.tar.gz)

    cd $dir
}

