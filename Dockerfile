FROM node:5.9.1-slim

WORKDIR /usr/src/app
COPY external-scripts.json /usr/src/app
COPY hubot-scripts.json /usr/src/app
COPY package.json /usr/src/app
COPY bin /usr/src/app/bin
COPY scripts /usr/src/app/scripts
COPY node_modules /usr/src/app/node_modules

EXPOSE 80

CMD ["./bin/hubot", "--adapter", "slack"]
