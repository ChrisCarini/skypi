import configparser
import logging
import sys
import time
from logging.handlers import TimedRotatingFileHandler

import click

from src.skypi.config import CommandWithConfigParser, common_configure_options, config_file_option, LOCAL, REMOTE, \
    write_config_file, read_config_file
from src.skypi.constants import LOCAL_DATA_FILES_PATH
from src.skypi.killer import GracefulKiller
from src.skypi.relay import PiAwareRelay, LocalPiAwareRelay, RemotePiAwareRelay


@click.group()
def cli():
    pass


@cli.group(help="Configure a SkyPi relay for a *local* or *remote* PiAware installations.",
           short_help="Configure a SkyPi relay for a *local* or *remote* PiAware installations.")
def config():
    pass


@config.command(cls=CommandWithConfigParser(),
                help="Configure a relay for a *local* PiAware installation.",
                short_help="Configure a relay for a *local* PiAware installation.")
@common_configure_options
@click.option('--piaware-data-location', 'local_path', default=LOCAL_DATA_FILES_PATH, type=click.Path(),
              help="The local path of dump1090-fa output. Default: {0}".format(LOCAL_DATA_FILES_PATH))
@config_file_option
@click.pass_context
def local(ctx, local_path, config_file, *args, **kwargs):
    config = ctx.params['config']
    config[LOCAL] = {}
    config[LOCAL]['local_path'] = local_path
    write_config_file(config_obj=config, config_file=config_file)


@config.command(cls=CommandWithConfigParser(),
                help="Configure a relay for a *remote* PiAware installation.",
                short_help="Configure a relay for a *remote* PiAware installation.")
@common_configure_options
@click.option('--piaware-host', 'piaware_hostname', default=None,
              help="The hostname of the PiAware server running dump1090-fa; "
                   "if not set, we assume dump1090 is running locally, and act accordingly.")
@config_file_option
@click.pass_context
def remote(ctx, piaware_hostname, config_file, *args, **kwargs):
    config = ctx.params['config']
    config[REMOTE] = {}
    config[REMOTE]['piaware_hostname'] = piaware_hostname
    write_config_file(config_obj=config, config_file=config_file)


@cli.command(context_settings=dict(help_option_names=['--help', '-help']),
             help="Run a SkyPi relay based on the provided configuration.",
             short_help="Run a SkyPi relay based on the provided configuration.")
@click.option('--config-file', '--config', 'config_file', type=click.Path(), required=True)
def run(config_file):
    ##
    # Read in the configuration
    ##
    config: configparser.ConfigParser = read_config_file(config_file)
    is_config_local: bool = LOCAL in config.sections()
    is_config_remote: bool = REMOTE in config.sections()
    config_key: str = LOCAL
    if is_config_remote:
        config_key: str = REMOTE
    our_config: configparser.ConfigParser = config[config_key]
    log_level: str = our_config['log_level']

    ##
    # Create our logger
    ##
    formatter: logging.Formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
    log: logging.Logger = logging.getLogger(__name__)

    sysout_handler: logging.Handler = logging.StreamHandler(sys.stdout)
    sysout_handler.setLevel(log_level)
    sysout_handler.setFormatter(formatter)
    log.addHandler(sysout_handler)

    rotating_file_handler: logging.Handler = TimedRotatingFileHandler(filename="skypi.log",
                                                                      interval=1,
                                                                      when="D",
                                                                      backupCount=10)
    rotating_file_handler.setLevel(log_level)
    rotating_file_handler.setFormatter(formatter)
    log.addHandler(rotating_file_handler)

    log.setLevel(log_level)

    ##
    # Validate the configs...
    ##

    # Are we local and using a hostname?
    is_local: bool = PiAwareRelay.is_local()
    if is_local and is_config_remote:
        msg = "Remote configuration file identified, but local path ({}) exists on this host).".format(
            LOCAL_DATA_FILES_PATH)
        click.echo(msg)
        log.critical(msg)
        exit(1)

    # Was a piaware hostname and piaware data location both specified?
    if is_config_remote and is_config_local:
        msg = "Both local and remote configuration sections found in {}. " \
              "Please modify the configuration file to only contain either `local` *OR* `remote`.".format(config_file)
        click.echo(msg)
        log.critical(msg)
        exit(1)

    log.info("Passed in options:")
    log.info("\t{0}: {1}".format('config_file', config_file))
    log.info("\t{0}: {1}".format('remote_host', our_config['remote_host']))
    log.info("\t{0}: {1}".format('remote_user', our_config['remote_user']))
    log.info("\t{0}: {1}".format('remote_key', our_config['remote_key']))
    log.info("\t{0}: {1}".format('remote_path', our_config['remote_path']))
    log.info("\t{0}: {1}".format('skip_remote_dir_creation', our_config.getboolean('skip_remote_dir_creation')))
    log.info("\t{0}: {1}".format('duration_between_sends', our_config.getint('duration_between_sends')))
    log.info("\t{0}: {1}".format('update_history_every', our_config.getint('update_history_every')))
    log.info("\t{0}: {1}".format('reconnect_every_n_hrs', our_config.getint('reconnect_every_n_hrs')))
    log.info("\t{0}: {1}".format('log_level', log_level))

    ##
    # Initialize PiAware relays
    ##
    killer: GracefulKiller = GracefulKiller()

    if is_config_local:
        log.info("\t{0}: {1}".format('local_path', our_config['local_path']))
        relay: PiAwareRelay = LocalPiAwareRelay(halt_execution=killer.halt_execution,
                                                remote_host=our_config['remote_host'],
                                                remote_user=our_config['remote_user'],
                                                remote_key=our_config['remote_key'],
                                                remote_path=our_config['remote_path'],
                                                skip_remote_dir_creation=our_config.getboolean(
                                                    'skip_remote_dir_creation'),
                                                duration=our_config.getint('duration_between_sends'),
                                                local_path=our_config['local_path'],
                                                update_history_every=our_config.getint('update_history_every'),
                                                reconnect_every=our_config.getint('reconnect_every_n_hrs'),
                                                log=log)
    else:
        log.info("\t{0}: {1}".format('piaware_hostname', our_config['piaware_hostname']))
        relay: PiAwareRelay = RemotePiAwareRelay(halt_execution=killer.halt_execution,
                                                 remote_host=our_config['remote_host'],
                                                 remote_user=our_config['remote_user'],
                                                 remote_key=our_config['remote_key'],
                                                 remote_path=our_config['remote_path'],
                                                 skip_remote_dir_creation=our_config.getboolean(
                                                     'skip_remote_dir_creation'),
                                                 duration=our_config.getint('duration_between_sends'),
                                                 piaware_hostname=our_config['piaware_hostname'],
                                                 update_history_every=our_config.getint('update_history_every'),
                                                 reconnect_every=our_config.getint('reconnect_every_n_hrs'),
                                                 log=log)
    ##
    # Execute
    ##
    while not killer.halt_execution.is_set():
        try:
            log.info("Running the PiAwareRelay...")
            relay.run()
        except Exception as e:
            log.error("Exception thrown while running the PiAwareRelay: {}".format(e))

        if not killer.halt_execution.is_set():
            secs: float = 60
            end_time: float = time.time() + secs
            log.info("Sleeping for {} seconds while we wrap up this iteration...".format(secs))
            while time.time() < end_time and not killer.halt_execution.is_set():
                time.sleep(1)

    log.info("Exited PiAwareRelay.")
    exit(0)


if __name__ == "__main__":
    cli()
