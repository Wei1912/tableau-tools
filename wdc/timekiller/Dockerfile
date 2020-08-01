# Dockerfile

FROM node:14.7.0-slim

WORKDIR /app

COPY . /app

RUN npm install --global http-server

EXPOSE 8080

ENTRYPOINT ["bash", "./run.sh"]

CMD [ "5" ]
