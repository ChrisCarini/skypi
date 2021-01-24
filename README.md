# SkyPi

## Summary

SkyPi is a simple relay written in Python which allows people
running [FlightAware's PiAware](https://flightaware.com/adsb/)
to have the same internally accessible web page be externally accessible without opening any firewall ports. This is
accomplished by:

1) Cloning
   [FlightAware's dump1090 GitHub project `public_html`](https://github.com/flightaware/dump1090/tree/master/public_html)
   directory to an externally accessible website

2) SFTP-ing the necessary JSON files to the needed directory on the aforementioned externally accessible website over
   SSH

## Description

### Prerequisites

Before you get started, you will need the following already setup:

1) A Raspberry Pi configured with FlightAware's PiAware ([directions](https://flightaware.com/adsb/piaware/))
2) An externally accessible website
3) Key-Based SSH authentication setup for the following:
    - Local Computer -> Raspberry Pi
    - Local Computer -> External Host
    - Raspberry Pi -> External Host

### Quick Start

1) Open the `local_variables.sh` file, and modify the values as needed
2) Run `./install.sh install` and follow the prompts
3) **Profit.** Everything should be configured and running as expected.

### Configuration

Configuration of SkyPi running on your Raspberry Pi is done through the `/etc/skypi/config.local.ini` file.

Sane defaults are chosen, but if you would like to override them, please feel free to!

### Manpage

```bash
pi@skypi:~/skypi/bin$ ./skypi.pyz --help
Usage: skypi.pyz [OPTIONS]

Options:
  -s, --sleep-duration INTEGER    The maximum duration between data sending.
                                  Anything 5 or above may yield 'problem'
                                  notifications for stale data. Default: 4
  --piaware-host TEXT             The hostname of the PiAware server running
                                  dump1090-fa; if not set, we assume dump1090
                                  is running locally, and act accordingly.
  --piaware-data-location PATH    The local path of dump1090-fa output.
                                  Default: /run/dump1090-fa/
  -h, --remote-host TEXT          The remote host where we want to send the
                                  dump1090-fa files.  [required]
  -u, --remote-user TEXT          The remote user for connecting to the remote
                                  host.  [required]
  -k, --remote-key PATH           The SSH key of the remote user used when
                                  connecting to the remote host.  [required]
  -p, --remote-path PATH          The remote path in which to place the files
                                  from dump1090-fa.  [required]
  -d, --skip-remote-dir-creation  If set, we will skip attempting to create
                                  the remote directory upon initialization.
  -r, --reconnect-every INTEGER   The number of times to send data prior to
                                  reestablishing the ssh connection. Default:
                                  300
  -i, --update-history-every INTEGER
                                  The number of iterations between history
                                  updates (history updates take a while).
                                  Default: 240
  --log-level [CRITICAL|ERROR|WARN|INFO|DEBUG]
                                  The log level to use; valid options are:
                                  [CRITICAL, ERROR, WARN, INFO, DEBUG]
                                  Default: INFO
  -help, --help                   Show this message and exit.
pi@skypi:~/skypi/bin$
```

## Developing / Contributing

Contributions are welcome! Below are some quick steps for getting started developing.

### Getting Started (for development)

1) Clone the repo:
    ```bash
    git clone https://github.com/ChrisCarini/skypi.git
    ```
1) Create the virtual environment and activate
    ```bash
    python3.7 -m venv venv
    source ./venv/bin/activate
    ```
1) Install the needed dependencies
    ```bash
    pip install -r ./requirements.txt
    ```
1) Develop!
1) Once you have made your desired changes, you can test the full cycle by running the installation script from your
   local development machine.
    ```bash
    ./install.sh install
    ``` 

   _(**Note:** This will (a) prepare the external host, (b) install Python 3.7 on the Raspberry Pi, and (c) prepare the
   Raspberry Pi. After executing this successfully, you should have a fully working SkyPi setup and running.)_

### Notes

You need to ensure the following packages are installed on your raspberry pi in order to properly build the shiv.

```bash
# Let's update
sudo apt-get update -y

# Needed to compile Python 3.7 - ideally we can remove this once there is a built/distributed version as part of Raspbian
sudo apt-get install -y build-essential tk-dev libncurses5-dev libncursesw5-dev libreadline6-dev libdb5.3-dev \
                        libgdbm-dev libsqlite3-dev libssl-dev libbz2-dev libexpat1-dev liblzma-dev zlib1g-dev libffi-dev

# Needed for shiv
sudo apt-get install build-essential libssl-dev libffi-dev python-dev

# Needed for python3 virtualenv
sudo apt-get install python3-venv
```


