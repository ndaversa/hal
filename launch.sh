#!/bin/bash

while read -r line; do
  eval `printf "export %s='%s';" "$(echo $line | cut -d'=' -f1)" "$(echo $line | cut -d'=' -f2-)"`
done < pal.env
unset REDIS_URL

bin/hubot --adapter slack
