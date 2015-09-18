#!/bin/bash
#
# Deletes all jMeter run data.
#
##############################################

PWD=`pwd`
CURRENT_FILE_DIRECTORY=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

JMETER_DATA_DIR=${CURRENT_FILE_DIRECTORY}'/../jmeter_data'
jmeterruns=('logs/*.log' 'runs_outputs/*.output' 'runs_samples/*.jtl' 'runs/*.php')

for files in ${jmeterruns[@]}; do
    rm ${JMETER_DATA_DIR}/${files} > /dev/null 2>&1
done

exit 0