FROM node:8.11.2-slim

RUN apt-get update && apt-get install net-tools
WORKDIR /usr/src/app
COPY external-scripts.json /usr/src/app
COPY package.json /usr/src/app
COPY bin /usr/src/app/bin
COPY src /usr/src/app/src
COPY scripts /usr/src/app/scripts
COPY node_modules /usr/src/app/node_modules

EXPOSE 80

ENTRYPOINT ["/usr/src/app/bin/entrypoint"]
CMD ./bin/hubot --adapter slack | tee -a /data/hal.log
