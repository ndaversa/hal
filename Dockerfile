FROM node:5.9.1-slim

RUN mkdir -p /root/.ssh/
RUN echo $SSH_KEY > /root/.ssh/id_rsa; chmod 600 /root/.ssh/id_rsa; head -c 5 < /root/.ssh/id_rsa
RUN head -c 5 < /root/.ssh/id_rsa
RUN mkdir -p /usr/src/app
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
