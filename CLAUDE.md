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

## Updating Integration Versions

`_data/integrations.yml` controls which integration versions are shown in the compatibility matrix and which downstream integrations keep Hibernate project series in "limited-support" status. It needs periodic updates as upstream projects release new versions or end support.

### How it works

Each integration can define three lists:
- `active_series`: versions currently in active support (shown in matrix; gives series "limited-support" status for downstream integrations with `hibernate_involvement: true`)
- `els_series`: versions in extended life support (shown in matrix; gives series "els" status)
- `inactive_series`: versions to hide from the matrix (opposite approach — everything else is shown)

The `active_series`/`els_series` status marking only applies to integrations with `downstream: true` AND `hibernate_involvement: true` (Quarkus, WildFly, Red Hat EAP). For other integrations (Java, Spring Boot), these lists only affect matrix display.

### Integrations to check

Check each integration against its upstream source:

1. **Quarkus** (`active_series`)
   - Release planning: https://github.com/quarkusio/quarkus/wiki/Release-Planning
   - Red Hat support policy: https://access.redhat.com/support/policy/updates/red_hat_build_of_quarkus_notes
   - Keep current LTS versions (an LTS stays active ~6 months after the next LTS ships) and the latest non-LTS
   - When a new non-LTS releases, replace the old non-LTS entry; when an LTS expires, remove it

2. **WildFly** (`active_series`)
   - Releases: https://www.wildfly.org/news/
   - Included versions: https://github.com/wildfly/wildfly/blob/main/pom.xml
   - Typically only the latest release is active (no LTS model)

3. **Red Hat EAP** (`active_series` + `els_series`)
   - Lifecycle: https://endoflife.date/red-hat-jboss-eap or https://access.redhat.com/support/policy/updates/jboss_notes/
   - Move versions from `active_series` to `els_series` when they enter Extended Life Support
   - Remove from `els_series` when ELS ends (no more fixes)

4. **Java** (`inactive_series`)
   - Lifecycle: https://endoflife.date/oracle-jdk
   - Add non-LTS versions when they reach EOL (every 6 months after release)
   - Never add LTS versions (11, 17, 21, 25, ...) — they are not EOL'd
   - Don't add the most recent non-LTS (it's still current)

5. **Spring Boot** (`inactive_series`)
   - Lifecycle: https://endoflife.date/spring-boot
   - Add versions when both OSS and commercial support end
   - The Hibernate team maintains Spring Boot compatibility on a best-effort basis

### After updating

Run `rake test` to verify (see "Running Tests" above). Check that no project series unexpectedly changed lifecycle status by reviewing which series reference the integration versions you changed (grep for the integration key in `_data/projects/*/releases/*/series.yml`).
