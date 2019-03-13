#!/usr/bin/env bash

DIST_DIR=dist

# This will get set below if we're able to skip requirements installation
SKIP_REQUIREMENTS_INSTALL=false

function create_venv() {
  echo "create virtualenv..."
  python3.7 -m venv venv
  echo "done."
}

function enter_venv() {
  echo "entering virtualenv..."
  source ./venv/bin/activate
  echo "done."
}

function install_dependencies() {
  echo "include the needed dependencies..."
  pip install --upgrade -r ../requirements.txt --target ${DIST_DIR}/
  echo "done."
}

echo "clean old skypi.pyz..."
rm -r skypi.pyz
echo "done."


echo "check if the virtualenv is present..."
if [[ -d "venv/" ]]; then
  echo "virtualenv IS present."
else
  echo "virtualenv NOT present."
  create_venv
fi
enter_venv


echo "install shiv..."
pip install shiv
echo "done."


echo "check if the \"${DIST_DIR}/\" directory exists..."
if [[ -d "${DIST_DIR}/" ]]; then
  echo "\"${DIST_DIR}/\" IS present."

  echo "check if the \"${DIST_DIR}/\" directory has different requirements installed..."
  ls ${DIST_DIR} | grep -E -o ".*.(dist|egg)-info" | sed 's/-/==/' | sed 's/.dist-info//' | sed 's/-py3.7.egg-info//' > tmp_req.txt
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


if [[ "${SKIP_REQUIREMENTS_INSTALL}" = false ]]; then
  install_dependencies
fi


echo "copy the skypi sources into the distribution..."
cp -R ../src ${DIST_DIR}/
echo "done."


echo "shiv that sucker..."
shiv --site-packages ${DIST_DIR} --compressed -p '/usr/bin/env python3.7' -o skypi.pyz -e src.skypi.run.cli
echo "done."


echo "deactivate virtualenv..."
deactivate
echo "done."
