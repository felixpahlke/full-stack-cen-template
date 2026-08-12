# Stage 0, "build-stage", based on Node.js, to build and compile the frontend
FROM --platform=$BUILDPLATFORM registry.access.redhat.com/ubi8/nodejs-20 AS base

WORKDIR /app

USER root

ENV PNPM_HOME=/pnpm
ENV PATH=$PNPM_HOME:$PATH

RUN npm install --global corepack@0.32.0 && corepack enable

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml /app/
COPY frontend/package.json /app/frontend/package.json

RUN pnpm install --frozen-lockfile --filter frontend...

COPY ./frontend/ /app/frontend/


FROM base AS build-stage

ARG VITE_API_URL=${VITE_API_URL}
ARG VITE_TELEMETRY_ENABLED=${VITE_TELEMETRY_ENABLED}

RUN pnpm --filter frontend run build


# Stage 1, based on Nginx, to have only the compiled app, ready for production with Nginx
# FROM nginx:1
FROM ghcr.io/nginxinc/nginx-unprivileged:stable-alpine

EXPOSE 8080
COPY --from=build-stage /app/frontend/dist/ /usr/share/nginx/html

COPY ./frontend/nginx.conf /etc/nginx/conf.d/default.conf
COPY ./frontend/nginx-backend-not-found.conf /etc/nginx/extra-conf.d/backend-not-found.conf
