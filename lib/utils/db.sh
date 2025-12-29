# Db utilities
#
# config file for these utilities is in config.d/db.ini
#

#######################################################
# Usage - Help text describing how to use this utility
#######################################################
function usage() {
  cat << EOS

    Usage: ${0} [ command [arguments] ]

    This utility uses the config file config.d/db.ini

    Commands:
      help : print this help message. Also printed with an incorrect command
      install : install the database engine specified

EOS
}

#######################################################
# install mariadb
#
#######################################################
function db-install-mariadb() {
  local status=61 # assume failure

  # get data from config
  # admin user
  local db_admin="${DB_ADMIN}"
  local db_admin_password="${DB_ADMIN_PASSWORD}"

  # database and a user
  local db="${DB}"
  local db_character_set="${DB_CHARACTER_SET:-utf8mb4}"
  local db_collation="${DB_COLLATION:-utf8mb4_general_ci}"
  local db_user="${DB_USER}"
  local db_user_password="${DB_USER_PASSWORD}"

#echo -e "\nadm: ${db_admin}, ${db_admin_password}\ndb: ${db}\ncol: ${db_collation}"
#echo -e "usr: ${db_user}, ${db_user_password}\n"
#exit 0

  # 1. check su
  ensure_root

  # ok toproceed
  echo -e "\nInstalling MariaDb"

  # 2. is mariadb already installed?
  if [ "$(command -v mariadb)" ]; then
    echo -e "\nMariaDb is already installed"

  else
    # attempt to install
    apt install mariadb-server mariadb-client

    # if ok, then secure the instance
    if [ $? = 0 ]; then
      mariadb-secure-installation

      if [ $? != 0 ]; then
        echo -e "\nUnable to secure MariaDb installation"
        exit ${status}
      fi

    fi # secure instance

    echo -e "OK"

  fi # else, not installed

  # 3. mariadb ok - start the service, just in case
  echo -e "Attempting to start mariadb service"

  systemctl start mariadb

  if [ $? != 0 ]; then
    echo -e "Unable to start mariadb service"
    exit ${status}
  fi

  echo -e "OK"

  # 4. if admin user (db_admin) was defined, attempt to create one
  if [ -n "${db_admin}" ]; then
    # attempt to create DB admin
    echo -e "Attempting to create DB admin user ${db_admin}"

    result="$( mariadb_add_user '*' '${db_admin}' '${db_admin_password}' )"

    # if there was an error quit - chances are db user will error as well
    if [ $? != 0 ]; then
      echo -e "Error creating DB Admin user"
      echo -e "${result}"

      exit ${status}
    fi

    echo -e "OK"

  fi # db_admin

  # 5. if db was specified, create it
  if [ -n "${db}" ]; then

    echo -e "Attempting to create DB ${db}"

    # 5.1 attempt to create the DB
    qry=$( cat << EOS
      create database if not exists ${db}
        character set = '${db_character_set}'
        collate = '${db_collation}'
EOS
        )

    # echo -e "\n${qry}"
    result="$( mariadb_query "${qry}" )"

    if [ $? != 0 ]; then
      echo -e "Could not create database ${db}"
      echo -e "${result}"

      exit ${status}

    else
      # ok to proceed
      echo -e "OK - DB ${db} was created"

      # if a user was defined for this DB then add them
      if [ -n "${db_user}" ]; then
        # add this user as DB owner for the recently created DB
        echo -e "Attempting to add DB owner ${db_user} to DB ${db}"

        # result="$( mariadb_add_user '${db}' '${db_user}' '${db_user_password}' )"
        result="$( mariadb_add_user "${db}" "${db_user}" "${db_user_password}" )"

        if [ $? != 0 ]; then
          echo -e "Unable to create user ${db_user} in DB ${db}"
          echo -e "${result}"

          exit ${status}

        else
          echo -e "OK"
          let "status=0"

        fi

      fi # db user

    fi # else, db created ok

  fi # db specified

  exit ${status}
}


#######################################################
# Install a database engine
# Arguments:
#  $1 - the database engine to be installed
#
#######################################################
function db-install() {
  local status=61 # assume failure
  local db_engine="${1,,}"

  # can only be run by root
  ensure_root

  # install which engine?
  case "${db_engine}" in

    "help")
      usage
      ;;

    "mariadb")
      db-install-mariadb
      ;;

    *)
      usage
    ;;

  esac

}
