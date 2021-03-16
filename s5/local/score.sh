#!/usr/bin/env bash
# Copyright 2012-2014  Johns Hopkins University (Author: Daniel Povey, Yenda Trmal)
# Apache 2.0

[ -f ./path.sh ] && . ./path.sh

# begin configuration section.
cmd=run.pl
stage=0
stats=true
beam=6
word_ins_penalty=0.0,0.5,1.0
min_lmwt=7
max_lmwt=17
iter=final
#end configuration section.

echo "$0 $@"  # Print the command line for logging
[ -f ./path.sh ] && . ./path.sh
. parse_options.sh || exit 1;

if [ $# -ne 3 ]; then
  echo "Usage: $0 [--cmd (run.pl|queue.pl...)] <data-dir> <lang-dir|graph-dir> <decode-dir>"
  echo " Options:"
  echo "    --cmd (run.pl|queue.pl...)      # specify how to run the sub-processes."
  echo "    --stage (0|1|2)                 # start scoring script from part-way through."
  echo "    --min_lmwt <int>                # minumum LM-weight for lattice rescoring "
  echo "    --max_lmwt <int>                # maximum LM-weight for lattice rescoring "
  exit 1;
fi

data=$1
lang_or_graph=$2
dir=$3

symtab=$lang_or_graph/words.txt

for f in $symtab $dir/lat.1.gz $data/text; do
  [ ! -f $f ] && echo "score.sh: no such file $f" && exit 1;
done

ref_filtering_cmd="cat"
[ -x local/wer_output_filter ] && ref_filtering_cmd="local/wer_output_filter"
[ -x local/wer_ref_filter ] && ref_filtering_cmd="local/wer_ref_filter"
hyp_filtering_cmd="cat"
[ -x local/wer_output_filter ] && hyp_filtering_cmd="local/wer_output_filter"
[ -x local/wer_hyp_filter ] && hyp_filtering_cmd="local/wer_hyp_filter"

# Assume that the last _***** is the only part that specifies the utterance
# and before that specifies the recording

mkdir -p $dir/scoring

cat $data/text | LC_ALL= python local/combine_line_txt_to_paragraph.py | \
  $ref_filtering_cmd > $dir/scoring/test_filt.txt

for wip in $(echo $word_ins_penalty | sed 's/,/ /g'); do
  $cmd LMWT=$min_lmwt:$max_lmwt $dir/scoring/penalty_$wip/log/best_path.LMWT.log \
    lattice-scale --inv-acoustic-scale=LMWT "ark:gunzip -c $dir/lat.*.gz|" ark:- \| \
    lattice-add-penalty --word-ins-penalty=$wip ark:- ark:- \| \
    lattice-best-path --word-symbol-table=$symtab ark:- ark,t:- \| \
    utils/int2sym.pl -f 2- $symtab \| \
    local/combine_line_txt_to_paragraph.py \| \
    $hyp_filtering_cmd '>' $dir/scoring/penalty_$wip/LMWT.txt || exit 1;
done

for wip in $(echo $word_ins_penalty | sed 's/,/ /g'); do
  $cmd LMWT=$min_lmwt:$max_lmwt $dir/scoring/penalty_$wip/log/score.LMWT.log \
    cat $dir/scoring/penalty_$wip/LMWT.txt \| \
    compute-wer --text --mode=present \
    ark:$dir/scoring/test_filt.txt  ark,p:- ">&" $dir/wer_LMWT_$wip || exit 1;
done

for wip in $(echo $word_ins_penalty | sed 's/,/ /g'); do
  for lmwt in $(seq $min_lmwt $max_lmwt); do
    # adding /dev/null to the command list below forces grep to output the filename
    grep WER $dir/wer_${lmwt}_${wip} /dev/null
  done
done | utils/best_wer.sh  >& $dir/scoring/best_wer || exit 1

best_wer_file=$(awk '{print $NF}' $dir/scoring/best_wer)
best_wip=$(echo $best_wer_file | awk -F_ '{print $NF}')
best_lmwt=$(echo $best_wer_file | awk -F_ '{N=NF-1; print $N}')

if [ -z "$best_lmwt" ]; then
  echo "$0: we could not get the details of the best WER from the file $dir/wer_*.  Probably something went wrong."
  exit 1;
fi

if $stats; then
  mkdir -p $dir/scoring/wer_details
  echo $best_lmwt > $dir/scoring/wer_details/lmwt # record best language model weight
  echo $best_wip > $dir/scoring/wer_details/wip # record best word insertion penalty
  
  $cmd $dir/scoring/log/stats1.log \
    cat $dir/scoring/penalty_$best_wip/$best_lmwt.txt \| \
    align-text --special-symbol="'***'" ark:$dir/scoring/test_filt.txt ark:- ark,t:- \|  \
    utils/scoring/wer_per_utt_details.pl --special-symbol "'***'" \| tee $dir/scoring/wer_details/per_utt \|\
     utils/scoring/wer_per_spk_details.pl $data/utt2spk \> $dir/scoring/wer_details/per_spk || exit 1;
  
  $cmd $dir/scoring/log/stats2.log \
    cat $dir/scoring/wer_details/per_utt \| \
    utils/scoring/wer_ops_details.pl --special-symbol "'***'" \| \
    sort -b -i -k 1,1 -k 4,4rn -k 2,2 -k 3,3 \> $dir/scoring/wer_details/ops || exit 1;
  
  $cmd $dir/scoring/log/wer_bootci.log \
    compute-wer-bootci --mode=present \
      ark:$dir/scoring/test_filt.txt ark:$dir/scoring/penalty_$best_wip/$best_lmwt.txt \
      '>' $dir/scoring/wer_details/wer_bootci || exit 1;
  
  oov_rate=$(python local/get_oov_rate.py ${data}/text ${symtab})
  echo ${oov_rate} | tee $dir/scoring/wer_detail/oov_rate 
fi


