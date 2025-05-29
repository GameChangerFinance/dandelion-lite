#!/bin/bash

export PGPASSWORD=${POSTGRES_PASSWORD}

START_DATE=`date +%s`
CURRENT_BLOCK_TIME=`psql -qt \
                    -d ${POSTGRES_DB} -U ${POSTGRES_USER} -h ${POSTGRES_HOST} \
                    -c 'select time from block order by id desc limit 1;'`

[[ $var =~ ^-?[0-9]+$ ]]

# echo $CURRENT_BLOCK_TIME

date=$CURRENT_BLOCK_TIME
if [ "z$date" != "z" ] && date -d "$date" >/dev/null
then
  #echo "Valid date"
  echo "Block table available"
else
  #echo "Invalid date"
  echo "Block table not available yet"  
  exit 1
fi

CURRENT_DATE=`date +%s --date="$CURRENT_BLOCK_TIME"`

DIFFERENCE=$(( $START_DATE - $CURRENT_DATE ))

if [ "$DIFFERENCE" -lt "3600" ] ; then
    echo "OK $DIFFERENCE < 3600";
    exit 0;
else 
    echo "Syncing $DIFFERENCE > 3600";
    exit 1;
fi

