#!/bin/bash

PACKAGE_NAME="streaming-speech-classifier"
OUTPUT_DIR="src/model"
OUTPUT_FILENAME="rust_model.ot"
OUTPUT_PATH="$OUTPUT_DIR/$OUTPUT_FILENAME"
TMP_PATH="/tmp/$OUTPUT_FILENAME"
MODEL_URL="https://huggingface.co/microsoft/deberta-base-mnli/resolve/main/rust_model.ot"

# go to the root directory of the current Rust package
PACKAGE_ROOT="$(echo $0 | sed "s/\/[^/]*.sh$//; s/\/\?[^/]*$//")"
CURRENT_DIR="$(basename "$(pwd)")"
if [ ! -z "$PACKAGE_ROOT" ]; then
  cd "$PACKAGE_ROOT"
elif [ "$CURRENT_DIR" == "bin" ]; then
  cd ..
fi

# download the model
mkdir -p "$OUTPUT_DIR"
if [ -f "$TMP_PATH" ]; then
  # remove partially downloaded model
  rm -f "$TMP_PATH"
fi
wget -O "$TMP_PATH" "$MODEL_URL"
mv "$TMP_PATH" "$OUTPUT_PATH"