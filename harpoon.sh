#!/bin/bash

if ! which virtualenv 2>&1 > /dev/null; then
  echo "Please install virtualenv and then run this"
  exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TMP_DIR="$DIR/.harpoon"
if [[ ! -d $TMP_DIR ]]; then
  opts=""
  if [[ -f /usr/bin/python2.7 ]]; then
    question="
import sys
if sys.version.startswith('2.7'): sys.exit(1)
    "
    if python -c "$question"; then
      opts=" -p /usr/bin/python2.7"
    fi
  fi

  if ! virtualenv $opts $TMP_DIR; then
    echo "Couldn't make the virtualenv :("
    rm -rf $TMP_DIR
    exit 1
  fi
fi

if [[ ! -f "$DIR/harpoon.yml" ]]; then
  echo "Please create a harpoon.yml next to this file"
  exit 1
fi

version_line=$(egrep "^harpoon_version" $DIR/harpoon.yml)
if [[ -z $version_line ]]; then
  echo "Please have a min_harpoon_version option in your harpoon.yml specifying the minimum version of harpoon you need"
  exit 1
fi

required_version="$(echo $version_line | cut -f2 -d:)"

source $TMP_DIR/bin/activate

update=0
if ! python -c "import harpoon"; then
  update=1
else
  if ! python <<<"
import sys; from distutils.version import LooseVersion; from harpoon import VERSION
if LooseVersion(VERSION) < LooseVersion($required_version):
  sys.exit(1)
" 2>&1 >/dev/null; then
    update=1
  fi
fi

if (($update==1)); then
  required_version=$(python -c "print $required_version.strip()")
  echo "Installing docker-harpoon==$required_version"
  pip install argparse
  pip install docker-harpoon==$required_version

fi
harpoon $@ --harpoon-config "$DIR/harpoon.yml"

