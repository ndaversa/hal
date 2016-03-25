#!/bin/bash
set -o allexport
source pal.env
unset REDIS_URL
set +o allexport

bin/hubot --adapter slack
