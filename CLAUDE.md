# Development Guide

This project requires running commands inside a containerized environment.

## Running Tests

To run RSpec tests:

```bash
podman run --rm -t --userns=keep-id -u $UID:$GID \
  -v $PWD:/home/dev/website:rw,Z \
  quay.io/hibernate/awestruct-build-env:latest \
  bundle exec rspec _spec/version_spec.rb
```

To run specific tests by pattern:

```bash
podman run --rm -t --userns=keep-id -u $UID:$GID \
  -v $PWD:/home/dev/website:rw,Z \
  quay.io/hibernate/awestruct-build-env:latest \
  bundle exec rspec _spec/version_spec.rb -e "initialize"
```

## Running the Build

To build the site (this will run tests automatically before generating):

```bash
podman run --rm -t --userns=keep-id -u $UID:$GID \
  -v $PWD:/home/dev/website:rw,Z \
  quay.io/hibernate/awestruct-build-env:latest \
  rake clean gen
```

To run only the tests without building:

```bash
podman run --rm -t --userns=keep-id -u $UID:$GID \
  -v $PWD:/home/dev/website:rw,Z \
  quay.io/hibernate/awestruct-build-env:latest \
  rake test
```

## Running Ruby Commands

To run Ruby commands or scripts:

```bash
podman run --rm -t --userns=keep-id -u $UID:$GID \
  -v $PWD:/home/dev/website:rw,Z \
  quay.io/hibernate/awestruct-build-env:latest \
  ruby script.rb
```

## Important Notes

- **Do NOT include** `-p 4242:4242` unless the server needs to be run, as port 4242 may already be in use
- The workspace directory must be mounted to `/home/dev/website`
- Use `--rm` to clean up the container after execution
- The `Z` flag on the volume mount handles SELinux contexts
