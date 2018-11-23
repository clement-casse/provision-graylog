# Packaged installation of [Graylog](https://www.graylog.org)

## Context

This project creates a standalone script that can be run on a CentOS / RedHat machine, it installs Docker and provision some `docker-compose.yml` files to rise Graylog as a log management system.
This script aims to provide a quick way to have a log management tool mainly for demonstration purpose.
This script is by no means suitable to deploy a production-ready Graylog instance.

## Execution requirements

The machine running the script should :

- run a CentOS / RedHat base capable of executing docker (CentOS 7+).
- be able to reach the internet to retrieve docker images, if a proxy is needed it should be present in the environment before executing the script.

The script must be run as the user **root** or with the `sudo` command.

## Instructions to run the script

By default the script is interactive : it will prompt if you accept default parameters and will let you overwrite them.
However it is possible to make the script completely autonomous by using the options `--assumeyes` and `--domain=DOMAIN`.
By doing so you decide to keep all default values.

## Contributing

### Modify the installation logic

The script is built using [`makeself`](https://makeself.io) : it creates a tar archive containing all the directory `./package` and embed it in the `installer.run` file.
Once executed the tar archive is expanded and the file `./package/bootstrap.sh` is run.

As a result if you want to modify the provisioning logic the file `./package/bootstrap.sh` should be modified.

### Making your own `installer.run` script file

The build is done with the `make` command, the file `Makefile` defines a `.PHONY` target called **package** which aliases **installer.run**.
The file `Makefile` is also used to download external dependencies like `GeoLite2-City.mmdb` and all the Graylog extensions.