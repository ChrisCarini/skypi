#!/usr/bin/env bash

BIN_NAME=$(basename "$0")
COMMAND_NAME=$1
SUB_COMMAND_NAME=$2

##
# CONSTANTS
##
ROOT_PATH=~/skypi
DIST_DIR="${ROOT_PATH}/dist"
SHIV_FILENAME="skypi.pyz"
EXPECTED_SKYPI_BUILD_PATH="${ROOT_PATH}/bin/${SHIV_FILENAME}"
SERVICE_FILENAME=skypi.service
SKYPI_BIN_DEST="/usr/local/skypi/"
SERVICE_LOG_DIR="/var/log/skypi"
SERVICE_FILE_SRC="${ROOT_PATH}/bin/service/${SERVICE_FILENAME}"
SERVICE_FILE_DST="/lib/systemd/system/${SERVICE_FILENAME}"
PYTHON_VERSION=3.12.9
PYTHON_VERSION_MAJOR_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f1,2)

##
# HELP TEXT
##
function sub_help() {
  echo "Usage: $BIN_NAME <command>"
  echo
  echo "Commands:"
  echo "   clean_files        Cleanup as many files as we can."
  echo "   install_python     Install Python ${PYTHON_VERSION}"
  echo "   build_shiv         Build the SkyPi shiv"
  echo "   install_shiv       Install the SkyPi shiv"
  echo "   install_service    Install the SkyPi service"
  echo "   help               This help message"
}

##
# FUNCTIONS
##
function sub_clean_files() {
  echo "Cleaning up files..."
  sudo rm -rf "$ROOT_PATH"
  sudo rm -f "$SKYPI_BIN_DEST${SHIV_FILENAME}"
  sudo rm -f "$SERVICE_FILE_SRC"
  sudo rm -f "$SERVICE_FILE_DST"
  sudo rm -f "/etc/skypi/config.local.ini"
  sudo rm -f "${SERVICE_LOG_DIR}/skypi.log*"
  echo "Done."
}

function sub_install_python() {
  # Update & install the needed packages
  sudo apt-get update -y
  sudo apt-get install -y build-essential tk-dev libncurses5-dev libncursesw5-dev libreadline6-dev libdb5.3-dev libgdbm-dev libsqlite3-dev libssl-dev libbz2-dev libexpat1-dev liblzma-dev zlib1g-dev libffi-dev

  # Download Python and install
  wget "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz"
  tar xf "Python-${PYTHON_VERSION}.tar.xz"
  cd "Python-${PYTHON_VERSION}"
  ./configure
  make -j 4
  sudo make altinstall

  # Upgrade pip - after installing, pip 10.0.1 is installed, and we want something newer (19.0.1, for example)
  sudo python$PYTHON_VERSION_MAJOR_MINOR -m pip install --upgrade pip

  # Remove all the artifacts we no longer need
  cd ..
  sudo rm -r "Python-${PYTHON_VERSION_MAJOR_MINOR}"
  rm "Python-${PYTHON_VERSION_MAJOR_MINOR}.tar.xz"
  # Choosing to leave the packages that were installed; the commands to remove are below:
  #sudo apt-get --purge remove build-essential tk-dev libncurses5-dev libncursesw5-dev libreadline6-dev libdb5.3-dev libgdbm-dev libsqlite3-dev libssl-dev libbz2-dev libexpat1-dev liblzma-dev zlib1g-dev libffi-dev -y
  #sudo apt-get autoremove -y
  #sudo apt-get clean
}

function sub_build_shiv() {
  # This will get set below if we're able to skip requirements installation
  SKIP_REQUIREMENTS_INSTALL=false

  if [[ -f "${SHIV_FILENAME}" ]]; then
    echo "shiv exists; clean old ${SHIV_FILENAME}..."
    rm -r "${SHIV_FILENAME}"
    echo "done."
  fi

  echo "check if the virtualenv is present..."
  if [[ -d "venv/" ]]; then
    echo "virtualenv IS present."
  else
    echo "virtualenv IS NOT present."
    echo "create virtualenv..."
    python$PYTHON_VERSION_MAJOR_MINOR -m venv venv
    echo "done."
  fi

  echo "entering virtualenv..."
  source ./venv/bin/activate
  echo "done."

  echo "install shiv..."
  pip install shiv
  echo "done."

  echo "check if the \"${DIST_DIR}/\" directory exists..."
  if [[ -d "${DIST_DIR}/" ]]; then
    echo "\"${DIST_DIR}/\" IS present."

    echo "check if the \"${DIST_DIR}/\" directory has different requirements installed..."
    ls ${DIST_DIR} | grep -E -o ".*.(dist|egg)-info" | sed 's/-/==/' | sed 's/.dist-info//' | sed "s/-py${PYTHON_VERSION_MAJOR_MINOR}.egg-info//" >tmp_req.txt
    REQ_DIFF=$(diff <(cat tmp_req.txt | sort) <(cat ../requirements.txt | sort))
    if [[ "$REQ_DIFF" != "" ]]; then
      echo "requirements ARE different - removing existing \"${DIST_DIR}/\"..."
      echo -e "DIFFERENCE:\n==BEGIN DIFF==\n"
      diff <(cat tmp_req.txt | sort) <(cat ../requirements.txt | sort)
      echo -e "\n==END DIFF=="
      rm -r ${DIST_DIR}
    else
      echo "requirements ARE NOT different - skip installing dependencies into \"${DIST_DIR}/\"..."
      SKIP_REQUIREMENTS_INSTALL=true
    fi
    rm tmp_req.txt
  else
    echo "\"${DIST_DIR}/\" NOT present."
  fi

  if [[ "${SKIP_REQUIREMENTS_INSTALL}" == false ]]; then
    echo "include the needed dependencies..."
    pip install --upgrade -r ../requirements.txt --target ${DIST_DIR}/
    echo "done."
  fi

  echo "copy the skypi sources into the distribution..."
  cp -R ../src ${DIST_DIR}/
  echo "done."

  echo "shiv that sucker..."
  shiv --site-packages "${DIST_DIR}/" --compressed -p "/usr/bin/env python${PYTHON_VERSION_MAJOR_MINOR}" -o "${SHIV_FILENAME}" -e src.skypi.run.cli
  echo "done."

  echo "deactivate virtualenv..."
  deactivate
  echo "done."
}

function sub_install_shiv() {
  if [[ ! -f "${EXPECTED_SKYPI_BUILD_PATH}" ]]; then
    echo "[ERROR] ${EXPECTED_SKYPI_BUILD_PATH} not found. Exiting."
    exit 1
  fi

  sudo mkdir -p "${SKYPI_BIN_DEST}"
  sudo cp "${EXPECTED_SKYPI_BUILD_PATH}" "${SKYPI_BIN_DEST}${SHIV_FILENAME}"
}

function sub_install_service() {
  echo "Copying ${SERVICE_FILENAME} FROM [${SERVICE_FILE_SRC}] TO [${SERVICE_FILE_DST}] ..."
  sudo cp "${SERVICE_FILE_SRC}" "${SERVICE_FILE_DST}"
  echo "Complete"

  echo "Creating log directory in [${SERVICE_LOG_DIR}] ..."
  sudo mkdir -p "${SERVICE_LOG_DIR}"
  sudo chown pi:pi /var/log/skypi/
  echo "Done"

  echo "Changing permissions, reloading systemctl daemons and enabling ${SERVICE_FILENAME} on $(hostname)..."
  sudo chmod 644 "${SERVICE_FILE_DST}" && sudo systemctl daemon-reload && sudo systemctl enable ${SERVICE_FILENAME}
  echo "Operations complete."
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
