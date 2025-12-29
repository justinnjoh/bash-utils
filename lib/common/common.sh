
# function to print error messages (can be any string) to STDERR (2)
function err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}


# is_root - returns true if current effective user EUID is root
# (ie it is 0) or false if user is not root
function is_root() {

  # echo -e "\nEUID: ${EUID}\n"

  if [[ "${EUID}" -eq "0" ]]; then
    return 0 # true
  else
    return 1 # false
  fi
}

# ensure root - if not root then exit script
function ensure_root() {
  local status=60 # assume failure

  if ! is_root; then
    echo -e "\nThis utility must be run as root. Please try sudo ${0} .."
    exit ${status}
  fi
}

# is_file - returns true if this is a file and false if it is not
function is_file() {
  if [[ -f "$1" ]]; then
    return 0 # true
  else
    return 1 # false
  fi
}

# is_directory - returns true if this is a directory and false if it is not
function is_directory() {
  if [[ -d "$1" ]]; then
    return 0 # true
  else
    return 1 # false
  fi
}

# print simple array items
function print_array() {
# Arguments:
#  $1 = the simple array
  local -n arr=${1:-()} # default to empty array

  IFS= # set Internal Field Separator to null, to avoid printing words of elem

  for item in "${arr[@]}"
  do
    echo "${item}"
  done

  return 0 # true
}

###########################################################
# Run a MariaDb query
# Assumptions:
# i) This will be run as 'root'
# ii) Calling script has checked that MariaDb is installed
# Arguments:
#  $1 = the sql string to run
#
###########################################################
function mariadb_query() {

  local status=61 # assume failure
  local qry="${1:-}"

  # query string is required
  if [ -z "${qry}" ]; then
    echo -e "An sql query is required"
    exit ${status}
  fi

  # ok to proceed
  # mariadb -N -u root -e ${qry} # no column headers
  mariadb -u root -e "${qry}"
  status=$? # result of query run - there could be an sql error

  exit ${status}
}

###########################################################
# MariaDb - add db owner
# Add a user and give them full access to the named DB
# The named DB could be *, giving the user ownership of all DBs
#
# Arguments:
#   $1 = the database - it must exist, if not *
#   $2 = the user name - it must currently not exist
#   $3 = password - required
###########################################################
function mariadb_add_user() {
  local status=61 # assume failure
  local db="${1:-}"
  local user="${2:-}"
  local password="${3:-}"

  #echo -e "\ndb: $db\nusr: $user\npwd: $password\n"
  #exit 0

  # 1. validate
  if [ -z "${db}" ]; then
    echo -e "A database name is required"
    exit ${status}
  fi

  if [ -z "${user}" ]; then
    echo -e "A user name for the DB owner is required"
    exit ${status}
  fi

  if [ -z "${password}" ]; then
    echo -e "A password for the DB owner is required"
    exit ${status}
  fi

  # 2. DB must exist, if it is not *
  if [[ "${db}" != "*" ]]; then

    qry="show databases like '${db}'"
    result="$( mariadb_query "${qry}" )"

    echo "${result}" | grep "${db}" > /dev/null
    if [ $? != 0 ]; then
      echo -e "Database ${db} does not exist"
      exit ${status}
    fi

  fi

  # 3. create user only if user does not exist
  qry="select user from mysql.user where user='${user}'; "

  # result="$( mariadb_query ${qry} )" # this works too
  result="$( mariadb_query "${qry}" )"

  echo "${result}" | grep "${user}" > /dev/null
  if [ $? = 0 ]; then
    # same user was found in result
    echo -e "User ${user} already exists. No further action taken"

    let "status=0" # return success
  fi

  # create the user and give them ownership of the DB (or *)
  # below query should create a user automatically
  qry=$( cat << EOS
    grant all on ${db}.* to '${user}'@'localhost' identified by 
    '${password}' with grant option;
    flush privileges;
EOS
      )

  # echo -e "${qry}"
  # mariadb_query "${qry}" # NO GOOD : we do not get $?
  result="$( mariadb_query "${qry}" )"

  #echo -e "\nSTS: $?\n"

  if [ $? = 0 ]; then
    echo -e "DB user ${user} was created OK"
    let "status=0" # success

  else
    echo -e "Unable to create DB user ${user}"
  fi

  exit ${status}
}

###########################################################
# Remove a DB user (if they exist)
# If user doesn't exist, then success
# Arguments:
#   $1 = user to be removed
#
###########################################################
function mariadb_remove_user() {
  local status=61 # assume failure
  local user="${1:-''}"

  # 1. validate
  if [ -z "${user}" ]; then
    echo -e "A user name to be removed is required"
    exit ${status}
  fi

  # 2. remove user if they exist
  qry=$( cat << EOS
    drop user if exists '${user}'@'localhost'
EOS
      )

  # echo -e "${qry}"
  result="$( mariadb_query "${qry}" )"

  if [ $? = 0 ]; then
    echo -e "DB user ${user} was removed, if they existed"
    let "status=0" # success

  else
    echo -e "Unable to remove user ${user}"
  fi

  exit ${status}
}

###########################################################
# Create a self-signed SSL cert for the domain passed
# Config file is in ./config.d/ssl.ini
# Arguments:
#   $1 = required : the domain name
# Output:
#   2 files called private.pem (key) and cert.pem (certificate)
# Comments:
#  Call this function in a script in the 'lib' folder, so it has access
#  to ./config.d/ssl.ini
###########################################################
function create_self_signed_cert() {
  # ssl.ini is needed;
  # function is assumed called from 'lib' for access to ssl.ini to work
  ssl_ini_file="./config.d/ssl.ini"

  let status=61 # assume failure

  # get domain and other app-related variables
  url="${1:-${HOST_URL}}" # required - default to value in vhost.ini
  ssl_cert_dir="${SSL_CERT_DIR:-/etc/ssl/vhosts/${url,,}}"
  # ssl_cert_dir="."
  ssl_key_file="${ssl_cert_dir}/${SSL_KEY_FILE:-private.pem}"
  ssl_cert_file="${ssl_cert_dir}/${SSL_CERT_FILE:-cert.pem}"

  #echo -e "\nurl: $url\nssl dir: $ssl_cert_dir\nkey: $ssl_key_file\ncert: $ssl_cert_file"
  #exit 0

  # 1. requires openssl to be installed - if not, abort
  if ! [ "$(command -v openssl)" ]; then
    echo -e "Aborting - openssl is not installed"
    exit ${status}
  fi

  # 2. if url was not passed, abort
  if [ -z "${url}" ]; then
    echo -e "A domain name is required"
    exit ${status}
  fi

  # 3. check for existence of ini file - it should exist
  if ! is_file "${ssl_ini_file}"; then
    echo -e "No SSL ini file. Is script run from correct directory?"
    exit ${status}
  fi

  # 4. if cert dir doesn't exist, something is wrong
  if ! is_directory "${ssl_cert_dir}"; then
    echo -e "SSL certificates directory not found. Run vhost-create first"
    exit ${status}
  fi

  # 5. get ini file
  ssl_ini_text="$(cat ${ssl_ini_file})"
  ssl_ini_text="${ssl_ini_text/\$\{HOST_URL\}/${url}}"

  # 6. store activity in .temp/{ssl_temp} folder - for easy cleanup
  ssl_temp="./.temp/$(date +"%Y-%m-%d-%H-%M-%S")"
  ssl_ini="${ssl_temp}/ssl.ini" # temp configured ssl ini file
  # echo -e "\n${ssl_temp}\n$ssl_ini}"
  mkdir -p "${ssl_temp}"
  echo -e "${ssl_ini_text}" > "${ssl_ini}"

  # 6. create the certificate
  $(openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ${ssl_key_file} -out ${ssl_cert_file} -config ${ssl_ini})

  status=$? # if last command succeeded, this will zero 'status'

  # in any case, clean up
  rm -r "${ssl_temp}"

  return ${status}
}

###########################################################
# Get a value from STDIN (0) - a consistent way to get user input
# Arguments:
#   $1 = prompt; $2 = optional validation regex;
#   $3 is an error message to show if validation fails
#   $4 = max attempts; if passed, then stop and fail after this number of attempts
# Output:
#   the value obtained
##########################################################
function get_input() {
  # initialise with suitable values
  value=''
  status=0 # exit status - assume success
  let attempts=0

  # get arguments or use default values
  prompt=${1:-"Enter a value"}
  message="${prompt}" # prompt to user can have added messages
  pattern=${2:-''}
  error_message=${3:-"Invalid input - please try again"}
  let max_attempts=${4:-0}

  while [[ -z ${value} ]]; do
    read  -r -p "${message}" value
    (( attempts++ ))

    # if max_attempts is exceeded, exit
    if (( ${max_attempts} > 0 && ${attempts} > ${max_attempts} )); then
      status=65 # set status to failed

      echo -e "\nMaximum number of attempts (${max_attempts}) exceeded\n"

      value=''

      break
    fi

    # validate?
    # -n means 'not null'; -z means 'is null'
    if [[ -n "${pattern}" && ! ${value} =~ ${pattern} ]]; then
      value='' # nullify $value

      message="${error_message}"
      [[ ${max_attempts} > 0 ]] && message="Attempts ${attempts} of ${max_attempts} - ${message}"

      message=`echo -e "$message\n\n$prompt"`

    fi

  done

  echo ${value} # function output

  return ${status} # exit status
}
