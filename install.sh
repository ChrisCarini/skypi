#!/usr/bin/env bash

# Pull in our local variables
source ./local_variables.sh


BIN_NAME=$(basename "$0")
COMMAND_NAME=$1
SUB_COMMAND_NAME=$2

function sub_help() {
  echo "Usage: $BIN_NAME <command>"
  echo
  echo "Commands:"
  echo "   install                    Perform a full installation of SkyPi (configure local RaspberryPi and External Host)"
  echo "   prepare_external_host      Prepare the External Host"
  echo "   prepare_raspberry_pi       Prepare the RaspberryPi"
  echo "   update_raspberry_pi        Update the source files on the RaspberryPi"
  echo "   configure                  Prompt the user for configuration parameters for the connection between the RaspberryPi and the External Host"
  echo "   help                       This help message"
}

function sub_install() {
  sub_prepare_external_host
  sub_configure
  sub_prepare_raspberry_pi
}

function sub_update_raspberry_pi() {
  ssh -i ${PI_SSH_KEY} ${PI_USER}@${PI_HOSTNAME} "mkdir ~/skypi/"
  scp -i ${PI_SSH_KEY} -r ./{src/,bin/,requirements.txt} ${PI_USER}@${PI_HOSTNAME}:~/skypi/
}

# Prepare our external host - copies the prepare_web.sh script over and executes on the remote host
function sub_prepare_external_host() {
  scp -i ${EXTERNAL_HOST_SSHKEY} ./bin/prepare_web.sh ${EXTERNAL_HOST_USERNAME}@${EXTERNAL_HOST_HOSTNAME}:${EXTERNAL_HOST_PATH}/
  ssh -i ${EXTERNAL_HOST_SSHKEY} ${EXTERNAL_HOST_USERNAME}@${EXTERNAL_HOST_HOSTNAME} "cd ${EXTERNAL_HOST_PATH}/ ; ./prepare_web.sh"
}

function sub_prepare_raspberry_pi() {
  sub_update_raspberry_pi
  ssh -i ${PI_SSH_KEY} ${PI_USER}@${PI_HOSTNAME} "cd ~/skypi/bin ; ./build_shiv.sh && ./install_shiv.sh && ./install_service.sh"
}

function sub_configure() {
  CONFIG_FILE_NAME=config.local.ini

  # prompt for inputs
  echo -e "Configuring the PiAware host at ${PI_HOSTNAME} in order to allow it to connect
           to the External Host at ${EXTERNAL_HOST_HOSTNAME} to upload data."

  read -p "[External Host] Username:" ext_host_user
  read -p "[External Host] ${ext_host_user}'s SSH Key Path:" ext_host_key_path

  # write file
  echo "[common]" > ${CONFIG_FILE_NAME}
  echo "remote_host = ${EXTERNAL_HOST_HOSTNAME}" >> ${CONFIG_FILE_NAME}
  echo "remote_user = ${ext_host_user}" >> ${CONFIG_FILE_NAME}
  echo "remote_key = ${ext_host_key_path}" >> ${CONFIG_FILE_NAME}
  echo "remote_path = ${EXTERNAL_HOST_PATH}/data" >> ${CONFIG_FILE_NAME}
  echo "skip_remote_dir_creation = True" >> ${CONFIG_FILE_NAME}
  echo "duration_between_sends = 4" >> ${CONFIG_FILE_NAME}
  echo "update_history_every = 240" >> ${CONFIG_FILE_NAME}
  echo "reconnect_every_n_hrs = 1" >> ${CONFIG_FILE_NAME}
  echo "log_level = INFO" >> ${CONFIG_FILE_NAME}
  echo "" >> ${CONFIG_FILE_NAME}
  echo "[local]" >> ${CONFIG_FILE_NAME}
  echo "local_path = /run/dump1090-fa/" >> ${CONFIG_FILE_NAME}

  # preview file contents
  echo "Configuration file contents:"
  cat ${CONFIG_FILE_NAME} | sed 's/^/  /'

  # scp file over
  scp -i ${PI_SSH_KEY} -r ${CONFIG_FILE_NAME} ${PI_USER}@${PI_HOSTNAME}:~/

  # remove the local file
  rm ${CONFIG_FILE_NAME}

  # copy file over into correct location
  ssh -i ${PI_SSH_KEY} ${PI_USER}@${PI_HOSTNAME} "mv ~/${CONFIG_FILE_NAME} /etc/skypi/config.local.ini"
}


case ${COMMAND_NAME} in
  "" | "-h" | "--help")
    sub_help
    ;;
  *)
    shift
    sub_${COMMAND_NAME} $@
    if [[ $? = 127 ]]; then
      echo "'$COMMAND_NAME' is not a known command or has errors." >&2
      sub_help
      exit 1
    fi
    ;;
esac
