# Shibboleth IdP for ONLYOFFICE Workspace SSO

Deploys a test Shibboleth IdP in Docker and configures it for an ONLYOFFICE Workspace
service provider (SP). The IdP is built from
[ONLYOFFICE/dockerized-idp-testbed](https://github.com/ONLYOFFICE/dockerized-idp-testbed),
a fork of [UniconLabs/dockerized-idp-testbed](https://github.com/UniconLabs/dockerized-idp-testbed).

Full instructions: [Help Center article](https://helpcenter.onlyoffice.com/workspace/administration/control-panel-sso-shibboleth.aspx#creatingshibbolethidp_block).

The script:

- downloads the testbed to `/app/dockerized-idp-testbed-master` (an existing copy is stopped and replaced);
- replaces the testbed domain with your IdP domain;
- allows SAML requests from your SP domain and releases the attributes ONLYOFFICE needs
  (`mail`, `givenName`, `surname`, `mobile`, `title`, `l`);
- enables dynamic metadata loading from the SP;
- enables Single Logout unless `--no_slo` is set;
- creates an LDAP directory with test users;
- builds and starts the containers.

> [!WARNING]
> This is a test environment. All LDAP users, including `admin`, have the password `password`.
> Do not use it in production.

## Requirements

- CentOS 7, correct system time (ntp)
- Root privileges
- curl, unzip, Docker, Docker Compose (the `docker-compose` command)
- A domain name pointing to the machine

## Usage

```bash
chmod +x install.sh
./install.sh -id your-idp-domain.com -sd myportal-address.com [--no_slo]
```

| Parameter | Description |
|-----------|-------------|
| `-id`, `--idp_domain` | Domain name of the Shibboleth IdP machine |
| `-sd`, `--sp_domain` | Domain name of the ONLYOFFICE portal (SP) |
| `-nl`, `--no_slo` | Optional. Disables Single Logout |
| `-h`, `--help` | Shows help |

When the script prints `Server:main: Started`, the IdP is ready. Press `Ctrl+C` to stop watching the logs;
the containers keep running.

## Test users

| User | Email |
|------|-------|
| `student1` | `student1@<idp domain>` |
| `student2` | `student2@<idp domain>` |
| `student3` | `student3@<idp domain>` |
| `staff1` | `staff1@<idp domain>` |
