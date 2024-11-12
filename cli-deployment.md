# Full-Stack CEN Template - Deployment

This Readme will describe the deployment on OpenShift.

## Our journey to a successful deployment 🏁

The steps should be performed in this exact order.

1. [Preparation](#preparation)
2. [Deploying the Database](#database)
3. [Deploying the Backend](#backend) ⚠️ It will run with errors until the [config map](#env-config-map) is finished (which we can only finish in the end).
4. [Deploying the Frontend](#frontend)
5. [Finish up the Env Config Map](#env-config-map)
6. [Setup a deployment hook](#setup-a-deployment-hook)

### Before you start

Install the OpenShift CLI (if you haven't already)

```bash
brew install openshift-cli
```

Login to OpenShift (you can get the token from the OpenShift UI)

```bash
oc login --token=<token> --server=<server-url>
```

### Use the script

The following Steps in this Readme can be done with the script.

```bash
./scripts/deploy.sh
```

⬇ If you want to do it manually, follow the steps below. ⬇

### Preparation

1. Create a new project

```bash
oc new-project <your-project-name>
```

2. Create new ssh key pair _(just use this command or change the key-name if you like)_

```bash
ssh-keygen -N '' -f $HOME/.ssh/ocp-key -q <<< y > /dev/null
```

3. Add the private key to the OpenShift secret

```bash
oc create secret generic git-secret \
    --from-file=ssh-privatekey=$HOME/.ssh/ocp-key \
    --type=kubernetes.io/ssh-auth
```

4. Copy the content of `$HOME/.ssh/ocp-key.pub` and add it as a new Deploy Key to your GitLab/GitHub repository

```bash
cat $HOME/.ssh/ocp-key.pub
```

copy, then add it to your GitLab/GitHub repository

### Deploying the Database

- Create the Database

```bash
oc new-app --template=postgresql-persistent --param=POSTGRESQL_USER=<postgres-user> --param=POSTGRESQL_PASSWORD=<postgres-password>

```

- Create Database in Postgres (May need to wait a while for the DB to be ready)

```bash
oc exec -it $(oc get pods | grep postgresql | grep -v deploy | awk '{print $1}') -- psql -c 'CREATE DATABASE app;'
```

### Deploying the Frontend

- Create the Frontend

```bash
oc new-app --name=frontend --strategy=docker --context-dir=frontend --source-secret=git-secret <ssh-git-url>
```

- Expose the Frontend

```bash
oc create route edge frontend --service=frontend --port=8080
```

### Deploying the Backend

- Create the Backend

```bash
oc new-app --name=backend --strategy=docker --context-dir=backend --source-secret=git-secret <ssh-git-url>
```

- Setup Secret Map

```bash

FRONTEND_URL=$(oc get route frontend -o jsonpath='{.spec.host}')

oc create secret generic backend-envs \
    --from-literal=POSTGRES_PASSWORD=<changethis> \
    --from-literal=FIRST_SUPERUSER_PASSWORD=<changethis> \
    --from-literal=POSTGRES_DB=app \
    --from-literal=BACKEND_CORS_ORIGINS=https://$FRONTEND_URL \
    --from-literal=POSTGRES_PORT=5432 \
    --from-literal=POSTGRES_SERVER=postgresql \
    --from-literal=SECRET_KEY=<changethis> \
    --from-literal=PROJECT_NAME=<your_project_name> \
    --from-literal=POSTGRES_USER=postgres \
    --from-literal=ENVIRONMENT=production \
    --from-literal=FIRST_SUPERUSER=<myexampleadmin@email.com>
```

- Add the Secret Map to the Backend

```bash
oc patch deployment backend --patch '{"spec":{"template":{"spec":{"containers":[{"name":"backend","envFrom":[{"secretRef":{"name":"backend-envs"}}]}]}}}}'
```

### Setup CI/CD

- Get the Webhook URLs

```bash
FRONTEND_BASE_URL=$(oc describe bc/frontend | grep "Webhook Generic" -A 1 | tail -n 1 | tr -d ' ')
FRONTEND_SECRET=$(oc get bc frontend -o jsonpath='{.spec.triggers[*].generic.secret}')
echo ${FRONTEND_BASE_URL/<secret>/$FRONTEND_SECRET}
```

```bash
BACKEND_BASE_URL=$(oc describe bc/backend | grep "Webhook Generic" -A 1 | tail -n 1 | tr -d ' ')
BACKEND_SECRET=$(oc get bc backend -o jsonpath='{.spec.triggers[*].generic.secret}')
echo ${BACKEND_BASE_URL/<secret>/$BACKEND_SECRET}
```

- Put Webhook URLs in the GitLab/GitHub Repositories

### Optional

- Group the resources as one application

```bash
oc label deployment/frontend deployment/backend dc/postgresql app.kubernetes.io/part-of=<your-app-name>
```

<!-- 8. Create Extension in Postgres DB

```bash
oc exec -it $(oc get pods | grep postgresql | grep -v deploy | awk '{print $1}') -- psql -d app -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";'
``` -->
