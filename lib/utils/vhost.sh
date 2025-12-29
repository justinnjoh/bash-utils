# virtual hosts utilities
#
# config file for these utilities is in config.d/vhost.ini
# templates are in templates.d/*.conf
#

######################################################
# Usage - Help text describing how to use this utility
######################################################
function usage() {
  cat << EOS

    Usage: ${0} [ command [argumengs] ]

    This utility uses the config file config.d/vhost.ini and
    templates in directory templates.d

    Commands:
      help : print this help message. Also printed with an incorrect command
      create : create an apache2 virtual host application structure

EOS
}

######################################################
# create a vhost structure as follows:
# these values can also be set in the config file, vhost.conf
# url (HOST_URL): required
# content (APP_DIR): /var/www/vhosts/<host url>/
# logs (APP_LOGS_DIR): /var/log/vhosts/<host url>/
# ssl cert (SSL_CERT_DIR): /etc/ssl/vhosts/<host url>/
#
# Arguments: $1 = host url; if not passed look for HOST_URL in config file
#
# Output:
# Returns 0 for success or last error exit code
########################################################
function vhost-create() {
  # echo "Script: $0; Function: $FUNCNAME"

  echo -e "\nCreating an apache2 virtual host structure\n"

  local status=66 # assume failure

  # 1. check su - must run as SU
  ensure_root

  # 2. get host url
  local host_url="${1:-${HOST_URL}}"

  if [[ -z $host_url ]]; then
    # give up after 4 attempts
    host_url=$(get_input 'Enter virtual host url: ' '\w+' 'Please enter a valid url' 4)
  fi

  # 3. if host url is passed, proceed
  if ! [[ -z $host_url ]]; then

    # 3.1 app directory
    dir="${APP_DIR:-/var/www/vhosts/${host_url}}"
    echo -e "\nCreating App directory ${dir}"

    # ABORT if this directory already exists
    if is_directory "${dir}"; then
      echo -e "\nExiting - seems like a vhost already exists at ${dir}\n"

      exit ${status}
    fi

    mkdir -p "${dir}"
    if [[ ${?} -ne 0 ]]; then
      echo -e "\nUnable to create App directory in : ${dir}"
      exit ${status}
    fi
    echo -e "OK\n"

    # 3.2 logs folder
    dir="${APP_LOG_DIR:-/var/log/vhosts/${host_url}}"
    echo -e "\nCreating App log directory ${dir}"

    mkdir -p "${dir}"
    if [[ ${?} -ne 0 ]]; then
      echo -e "\nUnable to create App log directory in : ${dir}"
      exit ${status}
    fi
    echo -e "OK\n"

    # 3.3 ssl certs directory
    dir="${SSL_CERT_DIR:-/etc/ssl/vhosts/${host_url}}"
    echo -e "\nCreating SSL certificates directory ${dir}"

    mkdir -p "${dir}" "${dir}"
    if [[ ${?} -ne 0 ]]; then
      echo -e "\nUnable to create App SSL certificates directory in : ${dir}"
      exit ${status}
    fi
    echo -e "OK\n"

    # next step is to run the appropriate config process
    echo -e "All good so far. Now run the appropriate config process\n"


  fi # -z $host_url

  return ${status}
}

######################################################
# delete a vhost
# these values can also be set in the config file, vhost.conf
# url (HOST_URL): required
# content (APP_DIR): /var/www/vhosts/<host url>/
# logs (APP_LOGS_DIR): /var/log/vhosts/<host url>/
# ssl cert (SSL_CERT_DIR): /etc/ssl/vhosts/<host url>/
#
# Arguments: $1 = host url; if not passed look for HOST_URL in config file
#
# Output:
# Returns 0 for success or last error exit code
########################################################
function vhost-remove() {
  # echo "Script: $0; Function: $FUNCNAME"

  local apache2_conf_path="${APACHE2_CONF_PATH:-/etc/apache2/sites-available}"
  local status=66 # assume failure
  local commands=() # commands to be executed
  local i=0 # array counter

  # 1. check su - must run as SU
  ensure_root

  # 2. get host url
  local host_url="${1:-${HOST_URL}}"

  if [[ -z $host_url ]]; then
    # give up after 4 attempts
    host_url=$(get_input 'Enter virtual host url: ' '\w+' 'Please enter a valid url' 4)
  fi

  # 3. if host url is passed, proceed
  if ! [[ -z $host_url ]]; then

    # 3.1 app directory
    dir="${APP_DIR:-/var/www/vhosts/${host_url}}"


    # if this folder exists, place a command to delete it in 'commands'
    if is_directory "${dir}"; then
      commands[${i}]="rm -r ${dir}"
      let "i=i+1"
    fi

    # 3.2 logs folder
    dir="${APP_LOG_DIR:-/var/log/vhosts/${host_url}}"

    if is_directory "${dir}"; then
      commands[${i}]="rm -r ${dir}"
      let "i=i+1"
    fi

    # 3.3 ssl certs directory
    dir="${SSL_CERT_DIR:-/etc/ssl/vhosts/${host_url}}"

    if is_directory "$dir"; then
      commands[${i}]="rm -r ${dir}"
      let "i=i+1"
    fi

    # 3.4 config file - SSL config is assumed, with a -80.conf file
    # that redirects to https
    # these should be /etc/apache2/sites-available/{host_url}.conf
    # and /etc/apache2/sites-available/{host_url}-80.conf

    conf="${host_url}\.conf"
    conf80="${host_url}-80\.conf"

    if is_file "${apache2_conf_path}/${conf}"; then
      commands[${i}]="a2dissite ${conf}"
      let "i=i+1"

      commands[${i}]="rm ${apache2_conf_path}/${conf}"
      let "i=i+1"
    fi

    if is_file "${apache2_conf_path}/${conf80}"; then
      commands[${i}]="rm ${apache2_conf_path}/${conf80}"
      let "i=i+1"
    fi

    # 3.10 if there are commands to run, then ask user first
    if [[ ${#commands[*]} -gt 0 ]]; then
      echo -e "\n#############################"
      echo -e "The following commands will be run. This is final - THERE IS NO UNDO\n"

      print_array commands

      echo -e "\n############################"

      read -p "Please confirm you wish to run the above commands - yes or NO: " ans

      if [[ "${ans,,}" == "yes" ]]; then # ans if converted to lowercase

        # iterate and run each command - report failed commands
        local failed=()
        local i=0

        for cmd in ${commands[@]}; do

          echo "${cmd}" | bash

          if [[ $? != 0 ]]; then
            failed[${i}]="${cmd}"
            let "i=i+1"
          fi

        done

        # if there were failed commands, show user
        if [[ ${i} > 0 ]]; then

          echo -e "\n-----------------------------"
          echo -e "The following commands failed\n"

          print_array failed

          echo -e "\n-----------------------------\n"

        else
          echo -e "\nAll commands were executed successfully\n"

        fi

      else
        echo -e "\nOK - Nothing was done\n"
      fi

    else

      echo -e "\nNothing to do\n"

    fi # are there commands to run?

  fi # -z $host_url

  return ${status}
}


######################################################
# Create a self-signed certificate
# Use self-contained process in common.sh : create_self_signed_cert
# All checks and defaults are available in the common.sh process
#
# Certificates will be placed in the default ssl_cert directory
######################################################
function vhost-create-self-signed-cert() {
  # must be run as root
  ensure_root

  # ok to proceed
  echo -e "\nCreating self-signed certificate"
  echo -e "\nYou can replace the certificate files with yours later"

  create_self_signed_cert $1

  return $?
}

function vhost-configure() {
######################################################
# configure a virtual host using a templete (default: vhost-simple.conf)
# config values can also be set in the config file, vhost.conf
#
# ssl cert (SSL_CERT_FILE): /etc/ssl/vhosts/<host url>/private/cert.pem
#
######################################################

  :

}

