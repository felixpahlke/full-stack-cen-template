# Stage 0, "build-stage", based on Node.js, to build and compile the frontend
FROM node:20 AS base

WORKDIR /app

COPY package*.json /app/

RUN npm install

COPY ./ /app/

ARG VITE_API_URL=${VITE_API_URL}


FROM base as build-stage

RUN npm run build


# Stage 1, based on Nginx, to have only the compiled app, ready for production with Nginx
# FROM nginx:1
FROM nginxinc/nginx-unprivileged:stable-alpine

EXPOSE 8080
COPY --from=build-stage /app/dist/ /usr/share/nginx/html

COPY ./nginx.conf /etc/nginx/conf.d/default.conf
COPY ./nginx-backend-not-found.conf /etc/nginx/extra-conf.d/backend-not-found.conf
