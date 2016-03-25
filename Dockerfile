FROM node:5.9.1-slim

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY external-scripts.json /usr/src/app
COPY hubot-scripts.json /usr/src/app
COPY package.json /usr/src/app

COPY bin /usr/src/app/bin
COPY node_modules /usr/src/app/node_modules
COPY scripts /usr/src/app/scripts

EXPOSE 80

CMD ["./bin/hubot", "--adapter", "slack"]
