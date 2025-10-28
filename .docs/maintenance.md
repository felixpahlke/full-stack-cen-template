## Maintenance and Updates to the Template

If you are doing updates to the template, do it as following:

- start with the `local-auth` branch (this used to be the main branch) and then merge the changes into the other branches. This way will interfere with the other branches git-histories as little as possible.

  - commit your changes to the `local-auth` branch
  - checkout a different branch, e.g. `oauth-proxy`
  - merge the changes from the `local-auth` branch into the `oauth-proxy` branch using `git merge local-auth --no-commit`
  - checkout the next branch, e.g. `local-auth-custom-ui`
  - ... repeat for all branches
  - push the changes to the remote repository
