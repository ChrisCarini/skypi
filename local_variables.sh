#!/usr/bin/env bash

##
# Raspberry Pi - The below values are used when connecting from the local machine to the local Raspberry Pi running PiAware
##
PI_HOSTNAME=192.168.40.102
PI_USER=pi
PI_SSH_KEY=~/.ssh/id_rsa_pi_at_rpi2_skypi_chriscarini_com

##
# External Host - The below values are used when connecting from the local machine to the External Host
##
EXTERNAL_HOST_HOSTNAME=skypi.chriscarini.com
EXTERNAL_HOST_USERNAME=remote_pi
EXTERNAL_HOST_SSHKEY=~/.ssh/id_rsa_dreamhost_remote_pi_at_chriscarini.com_ssh_key
EXTERNAL_HOST_PATH=/home/remote_pi/skypi.chriscarini.com
