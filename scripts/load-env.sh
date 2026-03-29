#!/usr/bin/env bash
# Loaded automatically by Pixi on activation (pixi run / pixi shell).
# Exports all variables from .env into the current shell environment.

if [ -f ".env" ]; then
    set -a
    # shellcheck disable=SC1091
    source ".env"
    set +a
fi
