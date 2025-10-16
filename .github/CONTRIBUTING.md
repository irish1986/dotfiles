# Contributing guidelines

Raise a PR.

## `pre-commit` hooks

This project leverages `pre-commit` hooks to improve code quality and security.  This project uses the [pre-commit framework](https://pre-commit.com/) with its configuration file is `.pre-commit-config.yaml`.

Alternatively, you can use the [perk framework](https://github.com/j178/prek); an improved `pre-commit` re-engineered in Rust.  **This framework is still in active development but performance is insane!!!**

**Checklist to use pre-commit hooks:**

1. Install pre-commit:

   ```bash
   pip install pre-commit
   pre-commit --version
   ```

2. Install the hooks; optional run the update:

   ```bash
   pre-commit install --allow-missing-config
   pre-commit autoupdate
   ```

3. Run the hooks manually (optional):

   ```bash
   pre-commit run --all-files --color auto
   ```

## Coding Style

This project uses the following coding style:

- `.config\.markdown-lint.yml` for `markdown`
- `.config\.yaml-lint.yml` for `yaml`

Please follow these rules and if you wish to amend them; raise a PR explaining your proposed changes.

## Conventional Commits

This project follows [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) specification to create a clear and explicit commit history.

```text
<type>[optional scope]: <short description>

[optional body]

[optional footer]
```

- `MAJOR` Semantic Versioning are triggered by appending a **!** after the **type/scope**, or a commit that has a footer **BREAKING CHANGE:**.
- `MINOR` Semantic Versioning are triggered by using the **feat** type to indicate a new feature introduction to the codebase
- `PATCH` Semantic Versioning are triggered by using the **fix** type to indicate a bugfix to the codebase.
- **Other types** are of no Semantic Versioning impact as follows:
  - **build** for code changes impacting the local build process
  - **bump** for releasing the code
  - **chore** for on-going recurring activities (i.e.: dependencies update)
  - **ci** for code changes impacting the CI build process
  - **docs** for documentation changes
  - **perf** for performance improvement that does not change the code behavior
  - **refactor** for refactoring code without changing the code behavior
  - **revert** for revert code changes if required
  - **style** for style and lint the current code base
  - **test** for code changes impacting the test suites for this codebase
