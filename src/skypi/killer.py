import signal
import threading


# Borrowed from: https://stackoverflow.com/questions/18499497/how-to-process-sigterm-signal-gracefully
class GracefulKiller:
    halt_execution = threading.Event()

    def __init__(self):
        # Register signal handler to handle [Cmd]+[x] and `kill <pid>` cleanly.
        signal.signal(signal.SIGINT, self.exit_gracefully)
        signal.signal(signal.SIGTERM, self.exit_gracefully)

    def exit_gracefully(self, signum, frame):
        print(f"\n{signal.Signals(signum).name} - Setting flag to halt execution, please hold...")
        self.halt_execution.set()
