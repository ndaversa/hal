FROM node:5.9.1-slim

RUN mkdir -p /root/.ssh
ADD /data/id_rsa /root/.ssh/id_rsa

WORKDIR /usr/src/app
COPY external-scripts.json /usr/src/app
COPY hubot-scripts.json /usr/src/app
COPY package.json /usr/src/app
COPY bin /usr/src/app/bin
COPY scripts /usr/src/app/scripts

RUN npm install
COPY node_modules /usr/src/app/node_modules

EXPOSE 80

CMD ["./bin/hubot", "--adapter", "slack"]
