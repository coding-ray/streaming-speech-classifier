#!/bin/bash
# install Rust
if ! command -v cargo &> /dev/null; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
fi


# install apt dependecies to build rust-bert
CHECK_INSTALL_CANDIDATES="pkg-config libssl-dev build-essential"
INSTALL_CANDIDATES=""
for pkg in $CHECK_INSTALL_CANDIDATES; do
  if [[ -z "$(apt list $pkg 2> /dev/null | tail -1 | grep installed)" ]]; then
    INSTALL_CANDIDATES="$INSTALL_CANDIDATES $pkg"
  fi
done

if [[ ! -z $INSTALL_CANDIDATES ]]; then
  echo Installing $INSTALL_CANDIDATES ...
  sudo apt install -y $INSTALL_CANDIDATES
fi

# install LibTorch to run rust-bert
DEFAULT_LIBTORCH_PATH="$HOME/.local/share/libtorch"
echo Installing LibTorch to $DEFAULT_LIBTORCH_PATH ...
echo This may take 3 to 10 minutes.
if [ -z "$LIBTORCH" ] || ! [ -d $LIBTORCH ]; then
  mkdir -p $(sed -e "s/\/$//; s/\/[^/]\+$//" <<< $DEFAULT_LIBTORCH_PATH)
  cd /tmp
  wget https://download.pytorch.org/libtorch/cu118/libtorch-cxx11-abi-shared-with-deps-2.0.0%2Bcu118.zip
  unzip -q libtorch-cxx11-abi-shared-with-deps-2.0.0+cu118.zip
  mv libtorch $DEFAULT_LIBTORCH_PATH
  if [ -z "$LIBTORCH" ]; then
    tee -a ~/.bashrc << EOT
export LIBTORCH=\"$DEFAULT_LIBTORCH_PATH\"
export LD_LIBRARY_PATH=\"\${LIBTORCH}/lib:\$LD_LIBRARY_PATH\"
export PATH=\"\$HOME/.local/bin:\$PATH"
EOT
    . ~/.bashrc
  fi
fi