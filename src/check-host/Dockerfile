FROM node:18-slim

WORKDIR /app

COPY app/package.json ./
RUN npm install

COPY app .

CMD ["npm", "start"]