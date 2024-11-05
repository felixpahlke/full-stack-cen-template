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

## Preparation

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

5. Deploy Backend

<!-- look at env file for environment variables -->

```bash
oc new-app --name=backend --strategy=docker --context-dir=backend --source-secret=git-secret <ssh-git-url>
```

6. Deploy Frontend

```bash
oc new-app --name=frontend --strategy=docker --context-dir=frontend --source-secret=git-secret <ssh-git-url>
```

7. Create DB

```bash
oc new-app --template=postgresql-persistent --param=POSTGRESQL_DATABASE=app --param=POSTGRESQL_USER=<postgres-user> --param=POSTGRESQL_PASSWORD=<postgres-password>
```

<!-- 8. Create Extension in Postgres DB

```bash
oc exec -it $(oc get pods | grep postgresql | grep -v deploy | awk '{print $1}') -- psql -d app -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";'
``` -->

8. Expose the Frontend

<!-- tls settings? -->

```bash
oc create route edge frontend --service=frontend --port=8080
```

_NOTE_ This is not complete yet. UPCOMING:

_until then you can use the openshift ui to do this (check out [deployment.md](deployment.md))_

- [ ] Add Config Map to the Backend via CLI
- [ ] Create Webhook Secrets for Frontend & Backend vor CI/CD
- [ ] Get Webhook URL

<!-- 9. Get Webhook URL

```bash
oc get route frontend -o jsonpath='{.spec.host}'
``` -->
