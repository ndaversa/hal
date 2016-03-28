#!/bin/bash
killall node
while IFS='' read -r line; do export "$line"; done < pal.env
unset REDIS_URL

bin/hubot --adapter slack
