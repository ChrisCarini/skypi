#!/usr/bin/env bash

EXPECTED_SKYPI_BUILD_PATH=~/skypi/bin/skypi.pyz

if [[ ! -f "${EXPECTED_SKYPI_BUILD_PATH}" ]]; then
  echo "[ERROR] ${EXPECTED_SKYPI_BUILD_PATH} not found. Exiting."
  exit 1
fi

sudo mkdir -p /usr/local/skypi/
sudo cp ${EXPECTED_SKYPI_BUILD_PATH} /usr/local/skypi/