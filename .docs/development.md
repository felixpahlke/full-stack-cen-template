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

rename the `.env.example` to `.env` (This is not necessary if you setup via CLI)

```bash
mv .env.example .env
```

⬇️ For the Stack to work you will need to provide environment variables for the AppID Instance. ⬇️

## AppID Setup

#### Environment Variables

- You will need an AppID Instance (or a different Identity Provider) for Authentication. You can create one for free in the IBM Cloud. (https://cloud.ibm.com/catalog/services/app-id)
- In AppID go to "Applications" and click "Add Application". (Best practice: Create one for development and one for production)
- You will see your Application in the List -> Click on it and you will see the Environment Variables that you need.
- Fill out the `.env` file with the Environment Variables.

#### Recirect Urls

- In AppID go to "Manage Authentication" -> "Authentication Settings"
- Add the redirect URLs to you Application:
- local: http://localhost:4180/oauth2/callback
- prod (you can add this once you have deployed the oauth-proxy): \<url-to-your-deployed-oauth-proxy\>/oauth2/callback

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

Frontend, served through the Oauth-Proxy, with routes handled based on the path: http://localhost:4180

Backend, JSON based web API based on OpenAPI: http://localhost:8000

Automatic interactive documentation with Swagger UI (from the OpenAPI backend): http://localhost:8000/docs

You can get the Bearer Token on http://localhost:4180/token to authenticate in the Swagger UI

Adminer, database web administration: http://localhost:8080

**Note**: The first time you start your stack, it might take a minute for it to be ready. While the backend waits for the database to be ready and configures everything. You can check the logs to monitor it.

To check the logs, run (in another terminal):

```bash
docker compose logs
```

To check the logs of a specific service, add the name of the service, e.g.:

```bash
docker compose logs backend -f
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

Frontend (Oauth-Proxy): http://localhost:4180

Backend: http://localhost:8000

Automatic Interactive Docs (Swagger UI): http://localhost:8000/docs

Automatic Alternative Docs (ReDoc): http://localhost:8000/redoc

Adminer: http://localhost:8080
