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

## How To Use It

You can **just fork or clone** this repository and use it as is.

✨ It just works. ✨

### How to Use a Your Own Repository

If you want to have a private repository you can do the following:

- Create a new Git repo, for example `my-full-stack`.
- Clone this repository manually, set the name with the name of the project you want to use, for example `my-full-stack`:

```bash
git clone git@github.ibm.com:technology-garage-dach/full-stack-cen-template.git my-full-stack
```

- Enter into the new directory:

```bash
cd my-full-stack
```

- Set the new origin to your new repository, copy it from the GitHub interface, for example:

```bash
git remote set-url origin git@github.com:my-username/my-full-stack.git
```

- Add this repo as another "remote" to allow you to get updates later:

```bash
git remote add upstream git@github.ibm.com:technology-garage-dach/full-stack-cen-template.git
```

- Push the code to your new repository:

```bash
git push -u origin main
```

### Update From the Original Template

After cloning the repository, and after doing changes, you might want to get the latest changes from this original template.

- Make sure you added the original repository as a remote, you can check it with:

```bash
git remote -v

origin    git@github.com:my-username/my-full-stack.git (fetch)
origin    git@github.com:my-username/my-full-stack.git (push)
upstream    git@github.ibm.com:technology-garage-dach/full-stack-cen-template.git (fetch)
upstream    git@github.ibm.com:technology-garage-dach/full-stack-cen-template.git (push)
```

- Pull the latest changes without merging:

```bash
git pull --no-commit upstream main
```

This will download the latest changes from this template without committing them, that way you can check everything is right before committing.

- If there are conflicts, solve them in your editor.

- Once you are done, commit the changes:

```bash
git merge --continue
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
