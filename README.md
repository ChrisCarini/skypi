# SkyPi

## Summary
SkyPi is a simple relay written in Python which allows people running [FlightAware's PiAware](https://flightaware.com/adsb/) 
to have the same internally accessible web page be externally accessible without opening any firewall ports. This is 
accomplished by:
1) Cloning [FlightAware's dump1090 GitHub project `public_html`](https://github.com/flightaware/dump1090/tree/master/public_html) 
directory to an externally accessible website 
1) SFTP-ing the necessary JSON files to the needed directory on the aforementioned externally accessible website over SSH

## Description
### Prerequisites
Before you get started, you'll need the below already setup:
1) A Raspberry Pi configured with FlightAware's PiAware ([directions](https://flightaware.com/adsb/piaware/))
1) An externally accessible website
1) The below network connections (Key-Based SSH Authentication):
   - Local Computer -> Raspberry Pi
   - Local Computer -> External Host
   - Raspberry Pi -> External Host

### Quick Start
1) Open the `local_variables.sh` file and modify the values as needed.
1) Run `./install.sh install`

### Getting Started
The below directions assume you are using PiAware on a default `Raspbian` installation; if you are using another Linux 
OS, you may need to make some modifications. Several convenience scripts are within this repository's `./bin` directory
to make installation easier.

#### On the externally accessible web host
Overall, very little is needed from the externally accessable web host. We just want to copy the `public_html` folder of
 the [FlightAware's dump1090 GitHub project](https://github.com/flightaware/dump1090/) to the directory that is serving 
 the html files for our externally accessible webhost. A convenience script exists for us do to that.
1) SSH over to the externally accessible web host and `cd` into the directory serving the publicly accessible files.
1) Clone this repository
    ```bash
    git clone https://github.com/ChrisCarini/skypi.git
    ```
1) Run the convenience script to clone FlightAware's GitHub project and grab the desired files:
    ```bash
    ./skypi/bin/prepare_web.sh
    ```

#### On the Raspberry Pi
1) SSH over to the Raspberry Pi running PiAware - all subsequent commands assume you're on that host
1) Clone this repository on the Raspberry Pi
    ```bash
    git clone https://github.com/ChrisCarini/skypi.git
    ```
1) As of 2019-01-25, `Raspbian GNU/Linux 9 (stretch)` does not come with `Python 3.7` which is required; thus we will 
use the provided convenience script to:
    1) Install the required tools / dependencies to build Python 3.7 from sources
    1) Download the Python 3.7.0 release from [python.org](https://python.org)
    1) Configure, and `make` Python 3.7
    1) Upgrade `pip` within Python 3.7 to a newer version

    Execute this convenience script with the below command:
    ```bash
    ./skypi/bin/install_python3.7.sh
    ```
1) We make use of [shiv](https://github.com/linkedin/shiv) to create a self-contained Python app; again, a convenience
script is provided to create this:
    ```bash
    ./skypi/bin/build_shiv.sh
    ```
    
1) Once the above script is finished, we will now have a single file that is able to run the app. You can invoke it with 
    the below command, but view the [manpage](#Manpage) for specific configuration options.
    ```bash
    ./skypi.pyz --remote-host example.com \
                --remote-user remote_pi \
                --remote-key ~/.ssh/id_rsa_remote_pi_at_example.com \
                --remote-path /home/remote_pi/apache/public_html \
                --skip-remote-dir-creation \
                --reconnect-every 10 > ./skypi.log &
    ```
    You can then view the output of the command very simply with `tail`:
    ```bash
    tail -f ./skypi.log 
    ```

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
1) Once you have made your desired changes, you can test the full cycle by:
    1) Copying the needed files / directories from your development machine over to your Raspberry Pi:
    ```bash
    scp -r ./{src/,bin/,requirements.txt} pi@skypi_host:~/skypi/
    ``` 
    1) SSHing to your Raspberry Pi and 'Building' the SkyPi shiv:
    ```bash
    ssh pi@skypi_host
    cd ~/skypi/bin
    ./build_shiv.sh
    ```

### Notes
You need to ensure the following packages are installed on your raspberry pi in order to properly build the shiv.
```bash
# Let's update
sudo apt-get update -y

# Needed to compile Python 3.7 - ideally we can remove this once there is a built/distributed version as part of Rasbian
sudo apt-get install -y build-essential tk-dev libncurses5-dev libncursesw5-dev libreadline6-dev libdb5.3-dev \
                        libgdbm-dev libsqlite3-dev libssl-dev libbz2-dev libexpat1-dev liblzma-dev zlib1g-dev libffi-dev

# Needed for shiv
sudo apt-get install build-essential libssl-dev libffi-dev python-dev

# Needed for python3 virtualenv
sudo apt-get install python3-venv
```


