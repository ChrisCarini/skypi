#!/usr/bin/env bash

##
# Raspberry Pi - The below values are used when connecting from the local machine to the local Raspberry Pi running PiAware
##
PI_HOSTNAME=255.255.255.255
PI_USER=pi
PI_SSH_KEY=~/.ssh/id_rsa_pi_at_255.255.255.255

##
# External Host - The below values are used when connecting from the local machine to the External Host
##
EXTERNAL_HOST_HOSTNAME=example.com
EXTERNAL_HOST_USERNAME=example_user
EXTERNAL_HOST_SSHKEY=~/.ssh/id_rsa_example_user_at_example.com
EXTERNAL_HOST_PATH=/var/www/public_html
