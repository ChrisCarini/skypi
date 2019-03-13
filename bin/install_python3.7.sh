#!/usr/bin/env bash

# Update & install the needed packages
sudo apt-get update -y
sudo apt-get install -y build-essential tk-dev libncurses5-dev libncursesw5-dev libreadline6-dev libdb5.3-dev libgdbm-dev libsqlite3-dev libssl-dev libbz2-dev libexpat1-dev liblzma-dev zlib1g-dev libffi-dev

# Download Python 3.7.0 and install
wget https://www.python.org/ftp/python/3.7.0/Python-3.7.0.tar.xz
tar xf Python-3.7.0.tar.xz
cd Python-3.7.0
./configure
make -j 4
sudo make altinstall

# Upgrade pip - after installing, pip 10.0.1 is installed, and we want something newer (19.0.1, for example)
sudo python3.7 -m pip install --upgrade pip

# Remove all the artifacts we no longer need
cd ..
sudo rm -r Python-3.7.0
rm Python-3.7.0.tar.xz
# Choosing to leave the packages that were installed; the commands to remove are below:
#sudo apt-get --purge remove build-essential tk-dev libncurses5-dev libncursesw5-dev libreadline6-dev libdb5.3-dev libgdbm-dev libsqlite3-dev libssl-dev libbz2-dev libexpat1-dev liblzma-dev zlib1g-dev libffi-dev -y
#sudo apt-get autoremove -y
#sudo apt-get clean