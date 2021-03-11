#!/bin/bash

. ./path.sh

lexicon_type="baseline"

. ./utils/parse_options.sh

mkdir -p data/dict

if [[ $lexicon_type = "baseline" ]]; then
  ./local/prepare_baseline_dict.sh
elif [[ $lexicon_type = "wikipron" ]]; then
  local/prepare_wikipron_dict.sh
fi  
