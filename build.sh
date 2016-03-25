#!/bin/bash

cd node_modules
rm hubot-jira-bot
rm hubot-loki-bot
rm hubot-groups-bot
rm hubot-aws-bot
rm hubot-ical-topic-bot
rm hubot-victorops-bot
rm hubot-privileges
rm hubot-github-bot
rm hubot-reminder-bot
cd ..
npm install
docker-compose build
