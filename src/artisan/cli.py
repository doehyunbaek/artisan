import argparse
import sys

from artisan import run, speedometer, submit, judge, serve, mitm
from artisan.tools import format, get


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="artisan", description="Artisan CLI")
    subparsers = parser.add_subparsers(dest="command", required=True)

    run.register_subparser(subparsers)
    submit.register_subparser(subparsers)
    judge.register_subparser(subparsers)
    format.register_subparser(subparsers)
    get.register_subparser(subparsers)
    serve.register_subparser(subparsers)
    speedometer.register_subparser(subparsers)
    mitm.register_subparser(subparsers)

    args = parser.parse_args(argv)
    handler = getattr(args, "func", None)
    if handler is None:
        parser.print_help()
        return 2
    return handler(args)


if __name__ == "__main__":
    sys.exit(main())
