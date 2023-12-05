#!/bin/bash
BIN_NAME="ssc"

rm -f $BIN_NAME
cargo build
cp target/debug/streaming-speech-classifier $BIN_NAME