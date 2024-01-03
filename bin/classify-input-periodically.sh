#!/bin/bash
# run this script in the root of this project

# config
BIN="ssc"
BASE_DIR="/vd0/web/api-eai/storage"
INPUT_DIR="$BASE_DIR/input"
PENDING_DIR="$BASE_DIR/pending"
OUTPUT_DIR="$BASE_DIR/output"
OUTPUT_FILENAME="latest.txt"
OUTPUT_PATH="$OUTPUT_DIR/$OUTPUT_FILENAME"
MODEL_PATH="src/model/rust_model.ot"

verify_status() {
  if [ ! -f "Cargo.toml" ]; then
    echo "Please run this script in the root of this project with:"
    echo "  bin/$(basename $0)"
    exit 1
  fi

  if [ ! -f "$BIN" ]; then
    bin/build-binaries.sh
  fi

  if [ ! -f "$MODEL_PATH" ]; then
    echo -e "Downloading model. Please wait.\n\n"
    bin/download-model.sh
  fi

  mkdir -p $PENDING_DIR
}

# store latest input filename in latest_input
fetch_file() {
  local time_waited=0
  while true; do
    latest_input="$(ls "$INPUT_DIR" | sort | head -1)"
    if [ ! -z "$latest_input" ]; then break; fi
    echo -ne "\rTime waited (seconds): $time_waited" # \r deletes everything leading
    ((time_waited++))
    sleep 1
  done
  echo "" # compensate for no newline previously
}

load_content() {
  local input="$1"
  processing_input="$PENDING_DIR/$input"
  rm -f "$processing_input"
  mv "$INPUT_DIR/$input" "$processing_input"
  rm -f "$INPUT_DIR/*" # in case of old input files
  file_content="$(cat $processing_input | tr "\n" " " | awk '$1=$1')"
  echo "Processing: $input"
  echo -e "Content: \"$file_content\""
}

# $1: input fraction 1
# $2: input fraction 2
# $3: maximal differece (positive)
# return in stdout: if (abs($1 - $2) <= $3), then 1, else 0
diff_within() {
  diff=$(echo "$1 - $2" | bc -l)
  abs_val=${diff#-} # ${word#prefix} means remove prefix "prefix" from "$word"
  if (($(echo "$abs_val <= $3" | bc -l))); then echo 1; else echo 0; fi
}

# $1: input fraction
# $2: upper bound
# return in stdout: if ($1 < $2), then 1, else 0
less_than() {
  if (($(echo "$1 < $2" | bc -l))); then echo 1; else echo 0; fi
}

# $1: input fraction
# $2: lower bound
# return in stdout: if ($1 < $2), then 1, else 0
greater_than() {
  if (($(echo "$1 > $2" | bc -l))); then echo 1; else echo 0; fi
}

# run the binary and get elapsed time
run_ssc() {
  local input="$1"
  local time_start=$(date +%s.%N)
  raw_output="$(./"$BIN" "$input")"
  local time_end=$(date +%s.%N)
  printf "Time elapsed (seconds): %.3f\n" $(echo "$time_end - $time_start" | bc -l)
  echo -e "Raw result:\n$(echo "$raw_output" | sed -e "s/^/  /")"
}

get_best_category_index() {
  local input="$1"
  scores="$(
    echo -e "$input" |
      tail +2 |
      awk '{print $NF}' |
      tr "\n" " "
  )"
  local score_science="$(echo $scores | awk '{print $1}')"
  local score_politics="$(echo $scores | awk '{print $NF}')"
  if [ $(less_than $score_science 0.001) == 1 ] && [ $(less_than $score_politics 0.001) == 1 ]; then
    best_category_index=2
  elif [ $(diff_within $score_science $score_politics 0.01) == 1 ]; then
    # ambiguous answer
    echo "Got an ambiguous answer (difference <= 0.01), so stick with the old answer."
    best_category_index=$(cat $OUTPUT_PATH | awk -F" " '{print $1}')
  elif [ $(greater_than $score_science $score_politics) == 1 ]; then
    best_category_index=0
  else
    best_category_index=1
  fi
}

output_result() {
  local index="$1"
  local output_text=""
  case $index in
  0) output_text="0 Science" ;;
  1) output_text="1 Politics" ;;
  *) output_text="2 Unknown" ;;
  esac
  echo -n $output_text >"$OUTPUT_PATH"
  echo -e "Best matched: $output_text\n"
}

main() {
  verify_status # may exit directly
  echo -e "Streaming Speech Classifier (SSC) launched.\n"
  rm -rf "$PENDING_DIR/*"
  while true; do
    fetch_file                   # result in global latest_input
    load_content "$latest_input" # result in global processing_input and file_content
    if [ -z "$file_content" ]; then
      echo -e "No input, skip processing\n"
      continue
    fi
    run_ssc "$file_content"               # result in global raw_output
    rm -f "$processing_input"             # remove processed file
    get_best_category_index "$raw_output" # result in global best_category_index
    output_result "$best_category_index"  # result in file
  done
}

main
