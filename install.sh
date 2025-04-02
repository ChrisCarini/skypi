#!/usr/bin/env bash

# Pull in our local variables
source ./local_variables.sh

BIN_NAME=$(basename "$0")
COMMAND_NAME=$1
SUB_COMMAND_NAME=$2

##
# HELP TEXT
##
function sub_help() {
  echo "Usage: $BIN_NAME <command>"
  echo
  echo "Commands:"
  echo "   install                              [local] Perform a full installation of SkyPi (configure local RaspberryPi and External Host)"
  echo "   configure                            [local] Prompt the user for configuration parameters for the connection between the RaspberryPi and the External Host"
  echo "   update_raspberry_pi                  [RaspberryPi] Update all necessary files on the RaspberryPi"
  echo "   sub_install_python37_raspberry_pi    [RaspberryPi] Install Python 3.7 on the RaspberryPi"
  echo "   prepare_raspberry_pi                 [RaspberryPi] Prepare the RaspberryPi"
  echo "   cleanup_raspberry_pi                 [RaspberryPi] Cleanup as many files as we can on the RaspberryPi"
  echo "   prepare_external_host                [External Host] Prepare the External Host"
  echo "   help                                 [local] This help message"
}

##
# MAIN COMMANDS
##
function sub_install() {
  sub_prepare_external_host
  sub_configure
  sub_install_python37_raspberry_pi
  sub_prepare_raspberry_pi
}

function sub_configure() {
  CONFIG_FILE_NAME=config.local.ini

  # prompt for inputs
  echo ""
  echo "Configuring the PiAware host at [${PI_HOSTNAME}] to allow it to connect to the External Host"
  echo "at [${EXTERNAL_HOST_HOSTNAME}] to upload data."
  echo ""
  echo "The below prompts are asking for connection details from the RaspberryPi to External Host."
  echo ""
  echo "       .________________.                        .____________."
  echo "       |                |        __   _          |            |"
  echo "       |   FlightAware  |      _(  )_( )_        |  External  |"
  echo "       |  Raspberry Pi  | --> (_   _    _)  -->  |  Web Host  |"
  echo "       |________________|       (_) (__)         |____________|"
  echo "        ^ [${PI_HOSTNAME}]                               ^ [${EXTERNAL_HOST_HOSTNAME}]"
  echo ""

  remote_home_path=$(ssh -i ${PI_SSH_KEY} ${PI_USER}@${PI_HOSTNAME} 'echo ~')
  ext_host_key_path="${remote_home_path}/${EXTERNAL_HOST_SSHKEY}"

  # write file
  echo "[common]" >${CONFIG_FILE_NAME}
  echo "remote_host = ${EXTERNAL_HOST_HOSTNAME}" >>${CONFIG_FILE_NAME}
  echo "remote_user = ${EXTERNAL_HOST_USERNAME}" >>${CONFIG_FILE_NAME}
  echo "remote_key = ${ext_host_key_path}" >>${CONFIG_FILE_NAME}
  echo "remote_path = ${EXTERNAL_HOST_PATH}/data" >>${CONFIG_FILE_NAME}
  echo "skip_remote_dir_creation = True" >>${CONFIG_FILE_NAME}
  echo "duration_between_sends = 3" >>${CONFIG_FILE_NAME}
  echo "update_history_every = 240" >>${CONFIG_FILE_NAME}
  echo "reconnect_every_n_hrs = 1" >>${CONFIG_FILE_NAME}
  echo "log_level = INFO" >>${CONFIG_FILE_NAME}
  echo "" >>${CONFIG_FILE_NAME}
  echo "[local]" >>${CONFIG_FILE_NAME}
  echo "local_path = /run/dump1090-fa/" >>${CONFIG_FILE_NAME}

  # preview file contents
  echo "Configuration file contents:"
  cat ${CONFIG_FILE_NAME} | sed 's/^/  /'

  # scp file over
  scp -i ${PI_SSH_KEY} -r ${CONFIG_FILE_NAME} ${PI_USER}@${PI_HOSTNAME}:~/

  # remove the local file
  rm ${CONFIG_FILE_NAME}

  # copy file over into correct location
  ssh -i ${PI_SSH_KEY} ${PI_USER}@${PI_HOSTNAME} "sudo mkdir -p /etc/skypi && sudo mv ~/${CONFIG_FILE_NAME} /etc/skypi/config.local.ini"
}

# ---
# - RaspberryPi
# ---
function sub_update_raspberry_pi() {
  ssh -i ${PI_SSH_KEY} ${PI_USER}@${PI_HOSTNAME} "mkdir -p ~/skypi/"
  scp -i ${PI_SSH_KEY} -r ./{src/,bin/,requirements.txt} ${PI_USER}@${PI_HOSTNAME}:~/skypi/
}

function sub_install_python37_raspberry_pi() {
  sub_update_raspberry_pi
  ssh -i ${PI_SSH_KEY} ${PI_USER}@${PI_HOSTNAME} "cd ~/skypi/bin ; ./prepare_rpi.sh install_python37"
}

function sub_prepare_raspberry_pi() {
  sub_update_raspberry_pi
  ssh -i ${PI_SSH_KEY} ${PI_USER}@${PI_HOSTNAME} "cd ~/skypi/bin ; ./prepare_rpi.sh build_shiv && ./prepare_rpi.sh install_shiv && ./prepare_rpi.sh install_service"
}

function sub_cleanup_raspberry_pi() {
  sub_update_raspberry_pi
  ssh -i ${PI_SSH_KEY} ${PI_USER}@${PI_HOSTNAME} "cd ~/skypi/bin ; ./prepare_rpi.sh clean_files"
}

# ---
# - External Host
# ---
# Prepare our external host - copies the prepare_web.sh script over and executes on the remote host
function sub_prepare_external_host() {
  scp -i ${EXTERNAL_HOST_SSHKEY} ./bin/prepare_web.sh ${EXTERNAL_HOST_USERNAME}@${EXTERNAL_HOST_HOSTNAME}:${EXTERNAL_HOST_PATH}/
  ssh -i ${EXTERNAL_HOST_SSHKEY} ${EXTERNAL_HOST_USERNAME}@${EXTERNAL_HOST_HOSTNAME} "cd ${EXTERNAL_HOST_PATH}/ ; ./prepare_web.sh"
}

##
# THE MAIN BUSINESS
##
case ${COMMAND_NAME} in
"" | "-h" | "--help")
  sub_help
  ;;
*)
  shift
  sub_${COMMAND_NAME} $@
  if [[ $? == 127 ]]; then
    echo "'$COMMAND_NAME' is not a known command or has errors." >&2
    sub_help
    exit 1
  fi
  ;;
esac
