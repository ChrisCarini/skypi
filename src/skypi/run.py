import logging
import sys
import time

import click

from src.skypi.constants import LOCAL_DATA_FILES_PATH
from src.skypi.killer import GracefulKiller
from src.skypi.relay import PiAwareRelay, LocalPiAwareRelay, RemotePiAwareRelay


@click.command(context_settings=dict(help_option_names=['--help', '-help']))
@click.option('-s', '--sleep-duration', 'duration_between_sends', default=4, type=int,
              help="The maximum duration between data sending. "
                   "Anything 5 or above may yield 'problem' notifications for stale data. Default: 4")
@click.option('--piaware-host', 'piaware_hostname', default=None,
              help="The hostname of the PiAware server running dump1090-fa; "
                   "if not set, we assume dump1090 is running locally, and act accordingly.")
@click.option('--piaware-data-location', 'local_path', default=LOCAL_DATA_FILES_PATH, type=click.Path(),
              help="The local path of dump1090-fa output. Default: {0}".format(LOCAL_DATA_FILES_PATH))
@click.option('-h', '--remote-host', 'remote_host', required=True,
              help="The remote host where we want to send the dump1090-fa files.")
@click.option('-u', '--remote-user', 'remote_user', required=True,
              help="The remote user for connecting to the remote host.")
@click.option('-k', '--remote-key', 'remote_key', required=True, type=click.Path(),
              help="The SSH key of the remote user used when connecting to the remote host.")
@click.option('-p', '--remote-path', 'remote_path', required=True, type=click.Path(),
              help="The remote path in which to place the files from dump1090-fa.")
@click.option('-d', '--skip-remote-dir-creation', 'skip_remote_dir_creation', is_flag=True, default=False,
              help="If set, we will skip attempting to create the remote directory upon initialization.")
@click.option('-r', '--reconnect-every', 'reconnect_every_n_hrs', default=24,
              help="After this duration (in hours), the SSH connection will be reestablished. Default: 24 (hrs)")
@click.option('-i', '--update-history-every', 'update_history_every', default=240,
              help="The number of iterations between history updates (history updates take a while). Default: 240")
@click.option('--log-level', 'log_level', default='INFO',
              type=click.Choice(['CRITICAL', 'ERROR', 'WARN', 'INFO', 'DEBUG']),
              help="The log level to use; valid options are: [CRITICAL, ERROR, WARN, INFO, DEBUG] Default: INFO")
def main(duration_between_sends, piaware_hostname, local_path, remote_host, remote_user, remote_key, remote_path,
         skip_remote_dir_creation, reconnect_every_n_hrs, update_history_every, log_level):
    killer = GracefulKiller()

    # Create our logger
    log = logging.getLogger(__name__)
    handler = logging.StreamHandler(sys.stdout)
    handler.setLevel(log_level)
    formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
    handler.setFormatter(formatter)
    log.addHandler(handler)
    log.setLevel(log_level)

    log.info("Passed in options:")
    log.info("\t{0}: {1}".format('duration_between_sends', duration_between_sends))
    log.info("\t{0}: {1}".format('piaware_hostname', piaware_hostname))
    log.info("\t{0}: {1}".format('local_path', local_path))
    log.info("\t{0}: {1}".format('remote_host', remote_host))
    log.info("\t{0}: {1}".format('remote_user', remote_user))
    log.info("\t{0}: {1}".format('remote_key', remote_key))
    log.info("\t{0}: {1}".format('remote_path', remote_path))
    log.info("\t{0}: {1}".format('skip_remote_dir_creation', skip_remote_dir_creation))
    log.info("\t{0}: {1}".format('reconnect_every_n_hrs', reconnect_every_n_hrs))
    log.info("\t{0}: {1}".format('update_history_every', update_history_every))
    log.info("\t{0}: {1}".format('log_level', log_level))

    ##
    # Validate the inputs...
    ##

    # Are we local and using a hostname?
    is_local = PiAwareRelay.is_local(local_path)
    if is_local and piaware_hostname is not None:
        log.critical(
            "--piaware-host specified when we've identified files locally. "
            "Please re-execute without specifying a piaware-host, as the local path {} was found".format(local_path))
        exit(1)

    # Was a piaware hostname and piaware data location both specified?
    if piaware_hostname is not None and local_path is not LOCAL_DATA_FILES_PATH:
        log.critical("--piaware-host and --piaware-data-location are both specified. "
                     "Please select one or the other only.")
        exit(1)

    ##
    # Initialize PiAware relays
    ##
    if piaware_hostname is None:
        relay = LocalPiAwareRelay(halt_execution=killer.halt_execution,
                                  remote_host=remote_host,
                                  remote_user=remote_user,
                                  remote_key=remote_key,
                                  remote_path=remote_path,
                                  skip_remote_dir_creation=skip_remote_dir_creation,
                                  duration=duration_between_sends,
                                  local_path=local_path,
                                  update_history_every=update_history_every,
                                  reconnect_every=reconnect_every_n_hrs,
                                  log=log)
    else:
        relay = RemotePiAwareRelay(halt_execution=killer.halt_execution,
                                   remote_host=remote_host,
                                   remote_user=remote_user,
                                   remote_key=remote_key,
                                   remote_path=remote_path,
                                   skip_remote_dir_creation=skip_remote_dir_creation,
                                   duration=duration_between_sends,
                                   piaware_hostname=piaware_hostname,
                                   update_history_every=update_history_every,
                                   reconnect_every=reconnect_every_n_hrs,
                                   log=log)
    ##
    # Execute
    ##
    while not killer.halt_execution.is_set():
        try:
            log.info("Running the PiAwareRelay...")
            relay.run()
            if not killer.halt_execution.is_set():
                secs = 60
                log.info("Sleeping for {} seconds while we wrap up this iteration...".format(secs))
                time.sleep(secs)
        except Exception as e:
            log.error("Exception thrown while running the PiAwareRelay: {}".format(e))
            pass
    log.info("Exited PiAwareRelay.")
    exit(0)


if __name__ == "__main__":
    main()
