#!/bin/sh

## GLOBAL VARIABLES
__dir="$(cd "$(dirname "${0}")" && pwd)"
__user="${SUDO_USER:-$USER}"
__homeDir="$(eval echo ~"${__user}")"
__logger="systemd-cat"
__dockerVersion="18.09.0-3.el7"
__dockerComposeVersion="1.23.1"
__stacksDir="/etc/siem"
__graylogAdminPass="passroot"

loggerHelp() {
  local logger="${1}" && shift

  case ${logger} in
    stdout)
    printf 'logs will be outputed to stdout with the prompts'
    ;;

    systemd-cat)
    printf 'use journalctl -xe to see logs'
    ;;
  esac
}

log() {
  local level=${1} && shift
  local logger=${1} && shift

  case ${logger} in
    stdout)
    printf '%s [%s] %s: %s\n' \
      "$(date +%FT%T%Z)" \
      "$(echo ${level} | cut -c1-4 | tr '[:lower:]' '[:upper:]')" \
      "$(basename "${0}")" \
      "$(printf "${@}")"
    ;;

    systemd-cat)
    printf '%s\n' "$(printf "${@}")" | systemd-cat \
      --identifier="$(basename "${0}")" \
      --priority="${level}"
    ;;
  esac
}

DEBUG_log() {
  log 'debug' "${__logger}" "${@}"
}

INFO_log() {
  log 'info' "${__logger}" "${@}"
}

NOTICE_log() {
  log 'notice' "${__logger}" "${@}"
}

WARN_log() {
  log 'warning' "${__logger}" "${@}"
}

ERROR_log() {
  log 'err' "${__logger}" "${@}"
}

install_docker() {
  local docker_version="${1}" && shift

  local linux_distrib="$(. /etc/os-release; echo "$ID")"

  yum remove --quiet \
    docker \
    docker-client \
    docker-client-latest \
    docker-common \
    docker-latest \
    docker-latest-logrotate \
    docker-logrotate \
    docker-selinux \
    docker-engine-selinux \
    docker-engine \
  && {
    DEBUG_log 'function="install_docker" message="Cleaned some old version of Docker"'
  } || {
    ERROR_log 'function="install_docker" message="Cannot remove some old docker version"'
  }

  yum install --assumeyes --quiet \
    yum-utils \
    device-mapper-persistent-data \
    lvm2 \
  && {
    DEBUG_log 'function="install_docker" message="yum-utils lvm2 and device-mapper-persistent-data installed successfully"'
  } || {
    ERROR_log 'function="install_docker" message="Cannot install requirements for Docker"'
  }

  yum-config-manager --quiet \
    --add-repo \
    "https://download.docker.com/linux/${linux_distrib}/docker-ce.repo" \
  && {
    DEBUG_log 'function="install_docker" message="Docker repo added successfully"'
  } || {
    ERROR_log 'function="install_docker" message="Cannot add Docker repo to yum"'
  }

  yum install --assumeyes --quiet docker-ce-${docker_version} \
  && {
    DEBUG_log 'function="install_docker" message="Docker-CE installed successfully"'
  } || {
    ERROR_log 'function="install_docker" message="Cannot install Docker-CE at version %s"' "${docker_version}"
  }

  if [ ! -z "${HTTP_PROXY}" ]; then
    INFO_log 'function="install_docker" message="Proxy configuration detected, creating %s file"' "/etc/systemd/system/docker.service.d/http-proxy.conf"
    mkdir -p '/etc/systemd/system/docker.service.d/'
    envsubst < "${__dir}/docker-service-proxy.conf" > '/etc/systemd/system/docker.service.d/http-proxy.conf'
    systemctl daemon-reload
  else
    INFO_log 'function="install_docker" message="NO proxy configuration detected, skipping %s file creation"' "/etc/systemd/system/docker.service.d/http-proxy.conf"
  fi

  systemctl enable docker && systemctl start docker \
  && {
    DEBUG_log 'function="install_docker" message="Service docker enabled and started"'
  } || {
    ERROR_log 'function="install_docker" message="Cannot enable docker service"'
  }
}



install_docker_compose() {
  local dockerComposeVersion="${1}" && shift;

  curl -L "https://github.com/docker/compose/releases/download/${dockerComposeVersion}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/sbin/docker-compose \
  && {
    DEBUG_log 'function="install_docker_compose" message="docker-compose downloaded in /usr/sbin/"'
  } || {
    ERROR_log 'function="install_docker_compose" message="Cannot install docker-compose"'
  }

  chmod +x /usr/sbin/docker-compose
}


provision_base() {
  local baseDir="${1}" && shift

  case ${baseDir} in 
    /*) mkdir -p "${baseDir}" ;;
    *)  ERROR_log 'function="provision_base" message="Expected that Arg1 would be an absolute path"';;
  esac
}

provision_docker_networks() {
  docker network create "monitoring"
  docker network create "data-plane"

  sleep 5
}

deploy_common() {
  local baseDir="${1}" && shift;
  local domainName="${1}" && shift;

  yum install --assumeyes --quiet openssl
  # openssl genrsa -out "${__dir}/proxy/ssl/traefik-key.pem" 2048
  # openssl req -new -key "${__dir}/proxy/ssl/traefik-key.pem" -out "${__dir}/proxy/ssl/traefik.csr" \
  #   -subj "/C=NL/ST=Zuid Holland/L=Rotterdam/O=Sparkling Network/OU=IT Department/CN=${domainName}"

  cp --recursive "${__dir}/common" "${baseDir}"

  docker-compose -f "${baseDir}/common/docker-compose.yml" up -d
}

deploy_graylog() {
  local baseDir="${1}" && shift;
  local domainName="${1}" && shift;
  local graylogAdminPass="${1}" && shift;

  local graylogAdminSHA2=$(echo -n "${graylogAdminPass}" | sha256sum | cut -d" " -f1)

  cp --recursive "${__dir}/graylog" "${baseDir}"

  chown 101:101 "${baseDir}/graylog/elasticsearch/elasticsearch.yml" # because ES is started as UID 101 by entrypoint
  chown 1100:1100 -R "${baseDir}/graylog/engine/" # because graylog is started as UID 1100 by entrypoint
  export DOMAIN_NAME="${domainName}" GRAYLOG_ROOT_PASSWORD_SHA2="${graylogAdminSHA2}"
  envsubst < "${__dir}/graylog/docker-compose.yml" > "${baseDir}/graylog/docker-compose.yml"

  docker-compose -f "${baseDir}/graylog/docker-compose.yml" up -d
}

provision_injector() {
  local baseDir="${1}" && shift;
  local utilityInstallPath="${1}" && shift;

  cp --recursive "${__dir}/injector" "${baseDir}"
  cp "${__dir}/tp" "${utilityInstallPath}/tp"
  chmod 755 "${utilityInstallPath}/tp"

  docker-compose -f "${baseDir}/injector/docker-compose.yml" pull
}

printhelp() {
  echo "
  Usage:
    $(basename ${0}) [MAKESELF_OPTIONS] -- [OPTIONS]

  MakeSelf Options are not detailed here, use '$(basename ${0}) --help' to know what the options are.

  Options :
    -y            | These options make the script use default values everywhere except at the domain
    --yes         | name which has no default. Combine this option with '--domain=DOMAIN' to make
    --assumeyes   | this script be not interactive at all.

    --domain=DOMAIN | Provide the domain name that will be used to reach graylog web ui. An IP
                    | address can also be used. Avoid using localhost or 127.0.0.1.

    --log2stdout  | Do not print logs to systemd journal but to STDOUT
  "
}

main() {
  local user="${__user}"
  local interactive="yes"
  local domainName=""
  local utilityInstallPath="/usr/sbin"

  for option in "${@}"; do
    case ${option} in
      -y|--yes|--assumeyes)
      interactive="no"
      shift
      ;;

      --domain=*)
      domainName="${option#*=}"
      shift
      ;;

      --log2stdout)
      __logger="stdout"
      shift
      ;;

      -h|--help)
      printhelp && exit 0
      ;;

      -*)
      ERROR_log 'function="main" message="Unknown option %s"' "${option}"
      printhelp && exit -1
      ;;

      *)
      break
      ;;
    esac
  done

  echo "$(tput bold)$(tput setaf 1)
  ==============================================================================
  == Is interactive ? : ${interactive}
  == Using logger ${__logger} : $(loggerHelp "${__logger}")
  ==============================================================================
  $(tput sgr0)"

  [ "$(id -u)" = "0" ] && {
    DEBUG_log 'function="main" message="script running as root, OK."'
  } || {
    ERROR_log 'function="main" message="script failed because it has not been run as root"'
    echo "This script is aimed to be run as root. Aborting."
    exit
  }

  if [ ! "${domainName}" ]; then
    read -p "Please enter the domain name that will be used to reach all the Web-UI
    (or any IP address that can be used by client to reach the web server) : " domainName
  fi

  message="
  Docker is required, enter the version of docker you want to see installed on this machine."
  if [ "${interactive}" == "yes" ]; then
    read -p "${message} $(tput setaf 3)[ ${__dockerVersion} ]$(tput sgr0) " answer
    if [ "${answer}" ]; then
      __dockerVersion="${answer}"
    fi
  fi
  install_docker "${__dockerVersion}"

  message="
  Docker-compose is also required, enter the version of docker-compose you want to see installed on this machine."
  if [ "${interactive}" == "yes" ]; then
    read -p "${message} $(tput setaf 3)[ ${__dockerComposeVersion} ]$(tput sgr0) " answer
    if [ "${answer}" ]; then
      __dockerComposeVersion="${answer}"
    fi
  fi
  install_docker_compose "${__dockerComposeVersion}"

  provision_docker_networks

  message="
  Docker stacks files and application configuration will be stored on the disk"
  if [ "${interactive}" == "yes" ]; then
    read -p "${message} $(tput setaf 3)[ ${__stacksDir} ]$(tput sgr0) " answer
    if [ "${answer}" ]; then
      __stacksDir="${answer}"
    fi
  fi
  provision_base "${__stacksDir}"

  deploy_common "${__stacksDir}" "${domainName}"

  message="
  Graylog admin password need to be initialized, type the password of the user 'admin' of Graylog"
  if [ "${interactive}" == "yes" ]; then
    read -p "${message} $(tput setaf 3)[ ${__graylogAdminPass} ]$(tput sgr0) " answer
    if [ "${answer}" ]; then
      __graylogAdminPass="${answer}"
    fi
  fi

  deploy_graylog "${__stacksDir}" "${domainName}" "${__graylogAdminPass}"


  message="
  An utility script to do the workshop will be installed, type the path from where you want to launch it"
  if [ "${interactive}" == "yes" ]; then
    read -p "${message} $(tput setaf 3)[ ${utilityInstallPath} ]$(tput sgr0) " answer
    if [ "${answer}" ]; then
      utilityInstallPath="${answer}"
    fi
  fi

  provision_injector "${__stacksDir}" "${utilityInstallPath}"

  clear
  echo "$(tput bold)
  Graylog has finally been deployed !
    Graylog should be available very soon at http://${domainName}/
      ==> Username: admin
      ==> Password: ${__graylogAdminPass}

    You can also hit Elasticsearch REST API direclty at URI http://${domainName}/elastic/

    Proxy WebUI is available at http://${domainName}/traefik/

    By the way all the docker-compose.yml files are under ${__stacksDir}

  $(tput sgr0)"
}

main "${@}"
