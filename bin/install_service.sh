#!/usr/bin/env bash

SERVICE_FILE=skypi.service

echo "Copying ${SERVICE_FILE} FROM [~/skypi/bin/service/] TO [/lib/systemd/system/] ..."
sudo cp ~/skypi/bin/service/${SERVICE_FILE} /lib/systemd/system/
echo "Complete"

echo "Changing permissions, reloading systemctl daemons and enabling ${SERVICE_FILE} on ${PI_HOSTNAME}..."
sudo chmod 644 /lib/systemd/system/${SERVICE_FILE} && sudo systemctl daemon-reload && sudo systemctl enable ${SERVICE_FILE}
echo "Operations complete."
