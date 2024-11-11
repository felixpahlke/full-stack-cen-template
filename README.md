# Full Stack Client Engineering Template

## Technology Stack and Features

- ⚡ [**FastAPI**](https://fastapi.tiangolo.com) for the Python backend API.
  - 🧰 [SQLModel](https://sqlmodel.tiangolo.com) for the Python SQL database interactions (ORM).
  - 🔍 [Pydantic](https://docs.pydantic.dev), used by FastAPI, for the data validation and settings management.
  - 💾 [PostgreSQL](https://www.postgresql.org) as the SQL database.
- 🚀 [React](https://react.dev) for the frontend.
  - 💃 Using TypeScript, hooks, Vite, and other parts of a modern frontend stack.
  - 🎨 [Carboncn UI](https://www.carboncn.dev/) & [Carbon](https://carbondesignsystem.com/) for the frontend components.
  - 🤖 An automatically generated frontend client.
  - 🦇 Dark mode support.
- 🐋 [Docker Compose](https://www.docker.com) & [Rancher Desktop](https://rancherdesktop.io/) for development.
- 🔒 Secure password hashing by default.
- 🔑 JWT (JSON Web Token) authentication.
- 📫 Email based password recovery.
- 🚢 Deployment instructions using OpenShift.

_This Template is based on [full-stack-fastapi-template](https://github.com/fastapi/full-stack-fastapi-template)_

<table>
<tbody>
<tr>
<td>

### Dashboard Login

![API docs](img/login.png)

</td>
<td>

### Dashboard - Admin

![API docs](img/dashboard.png)

</td>
</tr>
<tr>
<td>

### Dashboard - Create User

![API docs](img/dashboard-create.png)

</td>
<td>

### Dashboard - Items

![API docs](img/dashboard-items.png)

</td>
</tr>
<tr>
<td>

### Dashboard - User Settings

![API docs](img/dashboard-user-settings.png)

</td>
<td>

### Dashboard - Dark Mode

![API docs](img/dashboard-dark.png)

</td>
</tr>
<tr>
<td>

### Interactive API Documentation

![API docs](img/docs.png)

</td>
<td></td>
</tr>

  </tbody>
</table>

### How to Use It

1. Setup with create-cen-app and choose "full-stack-cen-template"

```bash
npm create cen-app@latest
```

2. Or if you just want to clone it:

- Clone this repository manually, set the name with the name of the project you want to use, for example `my-full-stack`:

```bash
git clone git@github.ibm.com:technology-garage-dach/full-stack-cen-template.git my-full-stack
```

- Enter into the new directory:

```bash
cd my-full-stack
```

- Remove the old Git history and start fresh:

```bash
rm -rf .git
```

- Initialize a new Git repo:

```bash
git init
git add .
git commit -m "Initial commit"
git branch -m main
```

- Create a new Git repo, for example `my-full-stack`.
- Add the new remote repository as origin:

```bash
git remote add origin git@github.com:my-username/my-full-stack.git
```

- Push the code to your new repository:

```bash
git push -u origin main
```

## Development

General development docs: [development.md](./development.md).

## Deployment

Deployment docs: [deployment.md](./deployment.md).

This includes using Docker Compose, custom local domains, `.env` configurations, etc.

## Backend Development

Backend docs: [backend/README.md](./backend/README.md).

## Frontend Development

Frontend docs: [frontend/README.md](./frontend/README.md).

## Release Notes

Check the file [release-notes.md](./release-notes.md).

## License

The Full Stack FastAPI Template is licensed under the terms of the MIT license.
