# FastAPI Project - Development

## Preparation

### Dependencies

- [python](https://www.python.org/downloads/) _(>=3.10)_

- [node](https://nodejs.org/en/learn/getting-started/how-to-install-nodejs) _(>= 20)_

- [uv](https://docs.astral.sh/uv/getting-started/installation/) _(faster poetry alternative)_

- [open source docker runtime (e.g. colima)](https://github.com/abiosoft/colima/) _(Docker Desktop alternative)_

_Recommended:_

Formatters: (**important because** - otherwise a single change of one line of code could lead to a rather large git commit if you use different formatters.)

- [Prettier](https://prettier.io/docs/en/editors)
- [ruff formatter](https://marketplace.visualstudio.com/items?itemName=charliermarsh.ruff) _(and set it as your default formatter for python)_

### Environment Variables

rename the `.env.example` to `.env`

```bash
mv .env.example .env
```

For local development you don't have to necessarily edit the "changethis" passwords etc. Later when we move on to Deployment, we have to change it!

## Docker Compose

- Start your docker runtime (colima)

```bash
colima start
```

- Start the local stack with Docker Compose (make sure you are )

```bash
docker compose watch
```

- Now you can open your browser and interact with these URLs:

Frontend, built with Docker, with routes handled based on the path: http://localhost:5173

Backend, JSON based web API based on OpenAPI: http://localhost:8000

Automatic interactive documentation with Swagger UI (from the OpenAPI backend): http://localhost:8000/docs

Adminer, database web administration: http://localhost:8080

**Note**: The first time you start your stack, it might take a minute for it to be ready. While the backend waits for the database to be ready and configures everything. You can check the logs to monitor it.

To check the logs, run (in another terminal):

```bash
docker compose logs
```

To check the logs of a specific service, add the name of the service, e.g.:

```bash
docker compose logs backend
```

## Local Development

The Docker Compose files are configured so that each of the services is available in a different port in `localhost`.

For the backend and frontend, they use the same port that would be used by their local development server, so, the backend is at `http://localhost:8000` and the frontend at `http://localhost:5173`.

This way, you could turn off a Docker Compose service and start its local development service, and everything would keep working, because it all uses the same ports.

For example, you can stop that `frontend` service in the Docker Compose, in another terminal, run:

```bash
docker compose stop frontend
```

And then start the local frontend development server:

```bash
cd frontend
npm run dev
```

Or you could stop the `backend` Docker Compose service:

```bash
docker compose stop backend
```

And then you can run the local development server for the backend:

```bash
cd backend
fastapi dev app/main.py
```

When you are done, shut down all containers with

```bash
docker compose down
```

## Docker Compose files and env vars

There is a main `docker-compose.yml` file with all the configurations that apply to the whole stack, it is used automatically by `docker compose`.

The Docker Compose file uses the `.env` file containing configurations to be injected as environment variables in the containers.

After changing variables, make sure you restart the stack:

```bash
docker compose watch
```

## The .env file

The `.env` file is the one that contains all your configurations, generated keys and passwords, etc.

Depending on your workflow, you could want to exclude it from Git, for example if your project is public. In that case, you would have to make sure to set up a way for your CI tools to obtain it while building or deploying your project.

One way to do it could be to add each environment variable to your CI/CD system, and updating the `docker-compose.yml` file to read that specific env var instead of reading the `.env` file.

## Development URLs

Development URLs, for local development.

Frontend: http://localhost:5173

Backend: http://localhost:8000

Automatic Interactive Docs (Swagger UI): http://localhost:8000/docs

Automatic Alternative Docs (ReDoc): http://localhost:8000/redoc

Adminer: http://localhost:8080

MailCatcher: http://localhost:1080
