#!/bin/bash

WIDTH_ARG=""
if [ $# -ge 1 ]; then
  WIDTH_ARG="--width $1"
fi

sudo apt-get update -y
sudo apt-get install -y git autoconf automake libtool build-essential cloc time gawk python3 python3-pip python3-venv

python3 -m venv pash-venv
source pash-venv/bin/activate

TOP=$(cd "$(dirname "$0")" && pwd)
pip install --break-system-packages -r "$TOP/infrastructure/requirements.txt"
# will install dependencies locally.
PLATFORM=$(uname | tr '[:upper:]' '[:lower:]')

if [ "$PLATFORM" = "darwin" ]; then
  echo 'PaSh is not yet well supported on OS X'
  exit 1
fi


if [ $(groups $(whoami) | grep -c "sudo\|root\|admin") -ge 1 ]; then
  # only run this if we are in the sudo group (or it's doomed to fail)
  bash $TOP/pash/scripts/distro-deps.sh
fi
export PASH_TOP="$PWD/pash"
bash $TOP/pash/scripts/setup-pash.sh

cd "$TOP/pash/python_pkgs/sh_expand"
patch -p0 < "$TOP/infrastructure/systems/sh_expand_patch.patch"
cd $TOP

if [ -n "$WIDTH_ARG" ]; then
  export KOALA_SHELL="$TOP/pash/pa.sh $WIDTH_ARG"
else
  export KOALA_SHELL="$TOP/pash/pa.sh"
fi

echo "PaSh shell is $KOALA_SHELL"
echo "Remember to run 'source pash-venv/bin/activate' to activate the PaSh virtual environment"
