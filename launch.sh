#!/bin/bash

regex="^(.+)=(.+)$"
while IFS='' read -r line; do
  if [[ $line =~ $regex ]]
  then
    export "${BASH_REMATCH[1]}=${BASH_REMATCH[2]}"
  else
    echo "Unable to process $line"
  fi
done < pal.env
unset REDIS_URL

bin/hubot --adapter slack
