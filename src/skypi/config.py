import configparser
from typing import Callable

import click

REMOTE = 'remote'
LOCAL = 'local'


def get_config_parser() -> configparser.ConfigParser:
    return configparser.ConfigParser(default_section='common')


def read_config_file(config_file: str) -> configparser.ConfigParser:
    config: configparser.ConfigParser = get_config_parser()
    config.read(filenames=config_file)
    return config


def write_config_file(config_obj: configparser.ConfigParser, config_file: str) -> None:
    with open(config_file, 'w') as configfile:
        config_obj.write(configfile)


def CommandWithConfigParser() -> click.Command:
    class CustomCommandClass(click.Command):
        def invoke(self, ctx: click.Context):
            config: configparser.ConfigParser = get_config_parser()
            config[config.default_section] = {
                'remote_host': ctx.params['remote_host'],
                'remote_user': ctx.params['remote_user'],
                'remote_key': ctx.params['remote_key'],
                'remote_path': ctx.params['remote_path'],
                'skip_remote_dir_creation': ctx.params['skip_remote_dir_creation'],
                'duration_between_sends': ctx.params['duration_between_sends'],
                'update_history_every': ctx.params['update_history_every'],
                'reconnect_every_n_hrs': ctx.params['reconnect_every_n_hrs'],
                'log_level': ctx.params['log_level']
            }
            ctx.params['config'] = config

            return super(CustomCommandClass, self).invoke(ctx)

    return CustomCommandClass


def config_file_option(f: Callable) -> Callable:
    f = click.option('--config-file', '--config', 'config_file', type=click.Path())(f)
    return f


_global_config_options = [
    click.option('-h', '--remote-host', 'remote_host',
                 required=True,
                 help="The remote host where we want to send the dump1090-fa files."),

    click.option('-u', '--remote-user', 'remote_user',
                 required=True,
                 help="The remote user for connecting to the remote host."),

    click.option('-k', '--remote-key', 'remote_key',
                 required=True,
                 type=click.Path(),
                 help="The SSH key of the remote user used when connecting to the remote host."),

    click.option('-p', '--remote-path', 'remote_path',
                 required=True,
                 type=click.Path(),
                 help="The remote path in which to place the files from dump1090-fa."),

    click.option('-d', '--skip-remote-dir-creation', 'skip_remote_dir_creation',
                 is_flag=True,
                 default=False,
                 help="If set, we will skip attempting to create the remote directory upon initialization."),

    click.option('-s', '--sleep-duration', 'duration_between_sends',
                 default=4,
                 type=int,
                 help="The maximum duration between data sending. "
                      "Anything 5 or above may yield 'problem' notifications for stale data. Default: 4"),

    click.option('-i', '--update-history-every', 'update_history_every',
                 default=240,
                 help="The number of iterations between history updates."
                      "Note: history updates take a while. Default: 240"),

    click.option('-r', '--reconnect-every', 'reconnect_every_n_hrs',
                 default=24,
                 help="Reestablish the SSH connection every N hours. Default: 24 (hrs)"),

    click.option('--log-level', 'log_level',
                 default='INFO',
                 type=click.Choice(['CRITICAL', 'ERROR', 'WARN', 'INFO', 'DEBUG']),
                 help="The log level to use; valid options are: "
                      "[CRITICAL, ERROR, WARN, INFO, DEBUG] Default: INFO"),
]


def common_configure_options(func):
    for option in reversed(_global_config_options):
        func = option(func)
    return func
