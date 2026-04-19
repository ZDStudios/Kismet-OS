from __future__ import annotations

import argparse

import uvicorn

from .db import Database
from .hardware import profile_json
from .server import build_app


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run the Kismet OS agent")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=7731)
    parser.add_argument("--print-profile", action="store_true")
    return parser


def main() -> None:
    args = build_parser().parse_args()
    if args.print_profile:
        print(profile_json())
        return
    db = Database()
    app = build_app(db=db)
    uvicorn.run(app, host=args.host, port=args.port)
