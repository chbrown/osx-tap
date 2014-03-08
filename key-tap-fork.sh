#!/bin/bash

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as sudo"
  exit 1
fi

./key-tap </dev/null >/dev/null 2>/dev/null &
