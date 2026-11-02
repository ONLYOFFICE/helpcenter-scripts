# Seccomp profile for ONLYOFFICE Docs on KylinOS

A custom [seccomp security profile](https://docs.docker.com/engine/security/seccomp/) for running
the ONLYOFFICE Docs Docker container on Kylin Linux Advanced Server V10. Use it instead of
`--security-opt seccomp=unconfined` to keep the container restricted to the system calls
ONLYOFFICE Docs needs.

The profile allows a fixed list of system calls on x86_64 and blocks all others.

Full instructions: [Help Center article](https://helpcenter.onlyoffice.com/docs/installation/docs-community-install-docker-kylinos.aspx).

## Usage

Download the profile:

```bash
curl -L -o kylin-seccomp7.json https://raw.githubusercontent.com/ONLYOFFICE/helpcenter-scripts/master/docs/docs-community-install-docker-kylinos/kylin-seccomp7.json
```

Pass its path to `--security-opt seccomp=` when starting the container:

```bash
sudo docker run -i -t -d -p 80:80 --security-opt seccomp=/path/to/kylin-seccomp7.json --restart=always -e JWT_SECRET=my_jwt_secret onlyoffice/documentserver
```
