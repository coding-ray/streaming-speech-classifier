BIN_NAME="ssc"

rm $BIN_NAME
cargo build
cp target/debug/streaming-speech-classifier $BIN_NAME