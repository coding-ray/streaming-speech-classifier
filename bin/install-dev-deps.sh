#!/bin/sbashh
# install Rust
if ! command -v cargo &> /dev/null ; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
fi


# install dependecies to build rust-bert
CHECK_INSTALL_CANDIDATES="pkg-config libssl-dev build-essential"
INSTALL_CANDIDATES=""
for pkg in $CHECK_INSTALL_CANDIDATES; do
  if [[ -z "$(apt list $pkg 2> /dev/null | tail -1 | grep installed)" ]]; then
    INSTALL_CANDIDATES="$INSTALL_CANDIDATES $pkg"
  fi
done

if [[ ! -z $INSTALL_CANDIDATES ]]; then
  sudo apt install -y $INSTALL_CANDIDATES
fi