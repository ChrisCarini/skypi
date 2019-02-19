import ast
import logging
import os
import sys
import threading
import time
from contextlib import contextmanager
from datetime import timedelta
from logging import CRITICAL, DEBUG, ERROR, INFO, WARN

import requests
from paramiko import SSHClient, SFTPClient, ssh_exception

from src.skypi.constants import LOCAL_DATA_FILES_PATH


class PiAwareRelay:
    """
    Pi-Aware Relay. Do not use directly, use either LocalPiAwareRelay or RemotePiAwareRelay instead.
    """

    KNOWN_LOCAL_DATA_FILES_PATHS = LOCAL_DATA_FILES_PATH

    def __init__(self, halt_execution: threading.Event, remote_host: str, remote_user: str, remote_key: str,
                 remote_path: str, skip_remote_dir_creation: bool, duration: float, update_history_every: int,
                 reconnect_every: int,
                 log: logging.Logger = None):
        self.send_iteration = 0
        self.connected_at = time.time()
        self.halt_execution = halt_execution
        self.remote_host = remote_host
        self.remote_user = remote_user
        self.remote_key = remote_key
        self.remote_path = remote_path
        self.duration = duration
        self.update_history_every = update_history_every
        self.reconnect_every = reconnect_every
        if log is None:
            self.LOG = logging.getLogger(__name__)
            handler = logging.StreamHandler(sys.stdout)
            handler.setLevel(INFO)
            formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
            handler.setFormatter(formatter)
            self.LOG.addHandler(handler)
        else:
            self.LOG = log

        # Try to create the remote directory, if desired.
        if not skip_remote_dir_creation:
            self.log(level=INFO, msg="Trying to create the remote directory...")
            try:
                with self.sftp_client() as sftp:
                    try:
                        sftp.chdir(self.remote_path)
                    except IOError:
                        self.log(level=WARN,
                                 msg="Error chdir to remote directory [{}]. Does not exist.".format(self.remote_path))
                        try:
                            self.log(level=INFO,
                                     msg="Trying to make directory on remote host: {}".format(self.remote_path))
                            sftp.mkdir(self.remote_path)
                        except IOError:
                            self.log(level=ERROR,
                                     msg="IOError - remote directory [{}] likely exists.".format(self.remote_path))
            except ssh_exception.NoValidConnectionsError as e:
                self.log(level=CRITICAL,
                         msg="Unable to create / verify remote directory exists. Full Error: {0}".format(e))
                raise
            self.log(level=INFO, msg="Attempt at creating the remote directory complete.")
        self.log(level=INFO, msg="Initialization complete.")

    def send(self, sftp: SFTPClient) -> None:
        raise NotImplementedError

    def needs_connection_refresh(self):
        return time.time() >= self.connected_at + timedelta(hours=self.reconnect_every).total_seconds()

    def run(self) -> None:
        self.send_iteration = 0
        with self.sftp_client() as sftp:
            while not self.halt_execution.is_set() and \
                    sftp.get_channel().get_transport().is_active() and \
                    not self.needs_connection_refresh():
                start_time = time.time()
                self.send(sftp=sftp)
                # If the channel is not active, no sense waiting...
                if sftp.get_channel().get_transport().is_active():
                    self.wait(start_time=start_time)
            self.log(level=INFO, msg="Run loop completed.")
            self.log(level=INFO, msg="\tMessages Sent: {0}".format(self.send_iteration))
            self.log(level=INFO, msg="\thalt_execution = {0}".format(self.halt_execution.is_set()))
            self.log(level=INFO, msg="\tssh active = {0}".format(sftp.get_channel().get_transport().is_active()))
            self.log(level=INFO, msg="\tneeds connection refresh = {0}".format(self.needs_connection_refresh()))

    @contextmanager
    def sftp_client(self) -> SFTPClient:
        with SSHClient() as client:
            client.load_system_host_keys()

            self.log(level=INFO, msg="Connecting to remote host [{}]".format(self.remote_host))
            client.connect(hostname=self.remote_host, username=self.remote_user, key_filename=self.remote_key)
            self.connected_at = time.time()

            self.log(level=DEBUG, msg="Opening SFTP connection to remote host [{}]".format(self.remote_host))
            with client.open_sftp() as sftp:  # type: SFTPClient
                yield sftp
            self.log(level=DEBUG, msg="Closed SFTP connection to remote host [{}]".format(self.remote_host))
        self.log(level=INFO, msg="Closed SSH connection to remote host [{}]".format(self.remote_host))

    def wait(self, start_time: float = time.time()) -> None:
        sleep_duration = self.duration - ((time.time() - start_time) % 60.0)
        sleep_duration = 0 if sleep_duration < 0 else sleep_duration
        if not self.halt_execution.is_set():
            self.log(level=INFO, msg="Sleeping for {} seconds...".format(sleep_duration))
            time.sleep(sleep_duration)

    @staticmethod
    def is_local(path: str = KNOWN_LOCAL_DATA_FILES_PATHS) -> bool:
        return os.path.exists(path=path)

    def log(self, level: int = logging.ERROR, msg: str = ""):
        prepend = "{} - ".format(self.send_iteration) if isinstance(self.send_iteration, int) else ""
        self.LOG.log(level=level, msg="{}{}".format(prepend, msg))


class LocalPiAwareRelay(PiAwareRelay):
    def __init__(self, halt_execution: threading.Event, remote_host: str, remote_user: str, remote_key: str,
                 remote_path: str, skip_remote_dir_creation: bool, duration: float, update_history_every: int,
                 local_path: str, reconnect_every: int, log: logging.Logger = None):
        super(LocalPiAwareRelay, self).__init__(halt_execution=halt_execution,
                                                remote_host=remote_host,
                                                remote_user=remote_user,
                                                remote_key=remote_key,
                                                remote_path=remote_path,
                                                skip_remote_dir_creation=skip_remote_dir_creation,
                                                duration=duration,
                                                update_history_every=update_history_every,
                                                reconnect_every=reconnect_every,
                                                log=log)
        self.local_path = local_path

    def send(self, sftp: SFTPClient) -> None:
        for file in os.listdir(self.local_path):
            if self.send_iteration % self.update_history_every != 0 and (
                    file.startswith("history") and file.endswith(".json")):
                self.log(level=DEBUG, msg="Skipping file [{0}]; [{1}/{2}]...".format(file, self.send_iteration,
                                                                                     self.update_history_every))
                continue
            local_full_path = os.path.join(self.local_path, file)
            remote_full_path = os.path.join(self.remote_path, file)
            try:
                self.log(level=DEBUG, msg="Copying local file[{}] to remote file [{}]".format(local_full_path,
                                                                                              remote_full_path))
                sftp.put(local_full_path, remote_full_path)
            except IOError:
                self.log(level=ERROR,
                         msg="IOError trying to copy local file[{}] to remote file [{}]".format(local_full_path,
                                                                                                remote_full_path))
        self.send_iteration += 1


class RemotePiAwareRelay(PiAwareRelay):
    def __init__(self, halt_execution: threading.Event, remote_host: str, remote_user: str, remote_key: str,
                 remote_path: str, skip_remote_dir_creation: bool, duration: float, piaware_hostname: str,
                 update_history_every: int, reconnect_every: int, log: logging.Logger = None):
        super(RemotePiAwareRelay, self).__init__(halt_execution=halt_execution,
                                                 remote_host=remote_host,
                                                 remote_user=remote_user,
                                                 remote_key=remote_key,
                                                 remote_path=remote_path,
                                                 skip_remote_dir_creation=skip_remote_dir_creation,
                                                 duration=duration,
                                                 update_history_every=update_history_every,
                                                 reconnect_every=reconnect_every,
                                                 log=log)
        self.piaware_hostname = piaware_hostname

    def send(self, sftp: SFTPClient) -> None:
        receiver_data = self.get_data(file="receiver.json")
        self.send_data(sftp=sftp, data=receiver_data, filename="receiver.json")

        aircraft_data = self.get_data(file="aircraft.json")
        self.send_data(sftp=sftp, data=aircraft_data, filename="aircraft.json")

        if self.send_iteration % self.update_history_every == 0:
            for filename in ["history_{0}.json".format(num) for num in
                             range(0, ast.literal_eval(receiver_data)['history'])]:
                self.send_data(sftp=sftp, data=self.get_data(file=filename), filename=filename)

        self.send_iteration += 1

    def get_data(self, file: str = "aircraft.json") -> str:
        data: str = None
        self.log(level=DEBUG, msg="Getting data from {}".format(self.piaware_hostname))
        r = requests.get("http://{0}:8080/data/{1}?_={2}".format(self.piaware_hostname, file, int(time.time() * 1000)))
        if r.status_code == 200:
            data = str(r.text)
        return data

    def send_data(self, sftp: SFTPClient, data: str, filename: str) -> bool:
        remote_filename = os.path.join(self.remote_path, filename)
        with sftp.open(remote_filename, 'w') as f:
            try:
                self.log(level=DEBUG, msg="Writing data to remote file [{}]".format(remote_filename))
                f.write(data=data)
            except IOError:
                self.log(level=ERROR, msg="IOError trying to write data to remote file [{}]".format(remote_filename))
                return False
        return True
