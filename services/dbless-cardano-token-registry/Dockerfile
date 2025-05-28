FROM node:16 AS build

COPY . /app
WORKDIR /app

RUN npm i 

ENTRYPOINT ["npm", "run", "start"]
