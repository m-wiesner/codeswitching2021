#!/bin/bash

if [ $# -ne 1 ]; then
  echo "Usage: ./local/prepare_data.sh <data>"
  exit 1;
fi

data=$1

mkdir data
cp -r ${data}/train/transcripts data/train
cp -r ${data}/test/transcripts data/test

for i in train test; do
  mv data/${i}/wav.scp data/${i}/wav.scp.bk
  awk -v var=${data}/${i} '{print $1, var"/"$2}' data/${i}/wav.scp.bk > data/${i}/wav.scp
  ./utils/fix_data_dir.sh data/${i}
done

exit 0;
