#!/usr/bin/env bash

DIST_DIR=dist


echo "clean old build..."
rm -r ${DIST_DIR} skypi.pyz
echo "done."

echo "create virtualenv..."
python3.7 -m venv venv
source ./venv/bin/activate
echo "done."

echo "include the needed dependencies..."
pip install -r ../requirements.txt --target ${DIST_DIR}/

# install shiv
pip install shiv
echo "done."

echo "copy the skypi sources into the distribution..."
cp -R ../src/skypi ${DIST_DIR}/
echo "done."

echo "shiv that sucker..."
shiv --site-packages ${DIST_DIR} --compressed -p '/usr/bin/env python3.7' -o skypi.pyz -e skypi.run.main
echo "done."


echo "deactivate virtualenv..."
deactivate
echo "done."
