FROM node:latest

ENV NODE_ENV production
ENV UV_THREADPOOL_SIZE 10

WORKDIR /app

COPY package-lock.json /app
COPY package.json /app
COPY public /app/public

RUN npm install --production

COPY index.js .

CMD ["node", "index.js"]
