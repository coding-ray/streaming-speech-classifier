# streaming-speech-classifier
Streaming Speech Classifier (SSC) is a time-critical pipeline that categorizes streaming audio (files).

## Getting Started

1. Clone this repository.
    ```
    git clone https://github.com/coding-ray/streaming-speech-classifier ssc
    cd ssc
    ```
1. Install development dependencies.
    ```
    ./bin/install-dev-deps.sh
    ```
1. Build the binaries, and move them to the current directory.
    ```
    ./bin/build-binaries.sh
    ```
1. Check the result.
    ```
    ./ssc "such a physics lecturer"
    ```
1. Measure the running time.
    ```
    time ./ssc "such a physics lecturer"
    ```
