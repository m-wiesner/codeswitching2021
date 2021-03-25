#!/bin/bash
# Change to Hindi-English to Bengali-English for the Bengali data
data=/export/corpora5/MultilingualCodeSwitching2021/codeswitching/104/Hindi-English 
trans_book=normalize/is21_hindi_english_filltered.csv

. ./path.sh
. ./cmd.sh

stage=0
stop_stage=8
lexicon_type="baseline" # baseline wikipron
language_tag=true

mode_dir="/export/b09/mwiesner/LFMMI_EBM2/LFMMI_EBM/tools/kaldi/egs/codeswitching/s5_updated_03_23_2021/exp/tri3"
lang="/export/b09/mwiesner/LFMMI_EBM2/LFMMI_EBM/tools/kaldi/egs/codeswitching/s5_updated_03_23_2021/data/lang_wikipron_norm_pd_sp"
input_data="data/train"
output_data="data/train_cleaned_linear_mat"
work_dir="exp/train_cleaned_linear_mat"

. ./utils/parse_options.sh

if [ $stage -le 0 ] && [ ${stop_stage} -ge 0 ]; then 
#  ./local/prepare_data.sh ${data}
  ./local/prepare_dict.sh 
  ./utils/prepare_lang.sh --share-silence-phones true \
    data/dict "<unk>" data/dict/tmp.lang data/lang_${lexicon_type}_nosp 
fi

# Feature extraction
# Stage 2: MFCC feature extraction + mean-variance normalization
if [ $stage -le 1 ] && [ ${stop_stage} -ge 1 ]; then
   for x in train test; do
      steps/make_mfcc.sh --nj 40 --cmd "$train_cmd" data/$x exp/make_mfcc/$x mfcc
      steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x mfcc
   done
fi

# Normalize
if [ $stage -le 2 ]; then
  local/wer_output_filter.py ${trans_book} < data/train/text > data/train/text_cleaned
fi

# Cleanup
#if [ $stage -le 3 ]; then
#  steps/cleanup/segment_long_utterances.sh --align-full-hyp true /export/b09/mwiesner/LFMMI_EBM2/LFMMI_EBM/tools/kaldi/egs/codeswitching/s5/exp/tri4 data/lang_baseline_nosp data/train data/train_cleaned_full exp/train_cleanup_full
#fi

# directly using Matthew's data
if [ $stage -le 3 ]; then
  echo "Copying data from Mattherw's dir"
  cp -r /export/b09/mwiesner/LFMMI_EBM2/LFMMI_EBM/tools/kaldi/egs/codeswitching/s5_updated_03_23_2021/data/train_norm data/train
fi

# Resegment using linear accpetor
if [ $stage -le 4 ]; then
  local/segment_long_utterances_with_linear_acceptor.sh ${model_dir} ${lang} ${input_data} ${output_data} ${work_dir}

fi
#if [ $stage -le 2 ] && [ ${stop_stage} -ge 2 ]; then
#  utils/subset_data_dir.sh --shortest data/train 500 data/train_500short
#  utils/subset_data_dir.sh data/train 5000 data/train_5k
#  utils/subset_data_dir.sh data/train 10000 data/train_10k
#fi
#
## Stage 3: Training and decoding monophone acoustic models
#if [ $stage -le 3 ] && [ ${stop_stage} -ge 3 ]; then
#  ### Monophone
#  echo "mono training"
#  steps/train_mono.sh --boost-silence 1.25 --nj 30 --cmd "$train_cmd" data/train_500short data/lang_${lexicon_type}_nosp exp/mono
#fi
#
## Stage 4: Training tied-state triphone acoustic models
#if [ $stage -le 4 ] && [ ${stop_stage} -ge 4 ]; then
#  ### Triphone
#  echo "tri1 training"
#  steps/align_si.sh --nj 40 --cmd "$train_cmd" \
#    data/train_5k data/lang_${lexicon_type}_nosp exp/mono exp/mono_ali_train_5k
#  steps/train_deltas.sh --boost-silence 1.25  --cmd "$train_cmd"  \
#    2000 10000 data/train_5k data/lang_${lexicon_type}_nosp exp/mono_ali_train_5k exp/tri1
#    echo "tri1 training done"
#fi
#
## More data
#if [ $stage -le 5 ] && [ ${stop_stage} -ge 5 ]; then
#  echo "tri2b training"
#  steps/align_si.sh --nj 40 --cmd "$train_cmd" \
#    data/train_10k data/lang_${lexicon_type}_nosp exp/tri1 exp/tri1_ali_train_10k
#
#  steps/train_deltas.sh --boost-silence 1.25  --cmd "$train_cmd"  \
#    2500 15000 data/train_10k data/lang_${lexicon_type}_nosp exp/tri1_ali_train_10k exp/tri1b
#fi
#
## Stage 5: Train an LDA+MLLT system.
#if [ $stage -le 6 ] && [ ${stop_stage} -ge 6 ]; then
#  steps/align_si.sh --nj 40 --cmd "$train_cmd" \
#      data/train data/lang_${lexicon_type}_nosp exp/tri1b exp/tri1b_ali
#  steps/train_lda_mllt.sh --cmd "$train_cmd" \
#    --splice-opts "--left-context=3 --right-context=3" 4200 40000 \
#    data/train_10k data/lang_${lexicon_type}_nosp exp/tri1b_ali exp/tri2
#fi
#
## Stage 6: Train tri3b, which is LDA+MLLT+SAT
#if [ $stage -le 7 ] && [ ${stop_stage} -ge 7 ]; then
#  steps/align_si.sh --use-graphs true --nj 40 --cmd "$train_cmd" \
#    data/train data/lang_${lexicon_type}_nosp exp/tri2 exp/tri2_ali
#
#  steps/train_sat.sh --cmd "$train_cmd" 4200 40000 \
#    data/train data/lang_${lexicon_type}_nosp exp/tri2_ali exp/tri3
#fi
#
## Add silence props
#if [ $stage -le 8 ] && [ ${stop_stage} -ge 8 ]; then
#  steps/get_prons.sh --cmd "$train_cmd" \
#    data/train data/lang_${lexicon_type}_nosp exp/tri3
#  utils/dict_dir_add_pronprobs.sh --max-normalize true \
#    data/dict \
#    exp/tri3/pron_counts_nowb.txt exp/tri3/sil_counts_nowb.txt \
#    exp/tri3/pron_bigram_counts_nowb.txt data/dict_sp
#
#  utils/prepare_lang.sh --share-silence-phones true data/dict_sp \
#    "<unk>" data/dict_sp/.lang_tmp data/lang_${lexicon_type}
#
#  ./steps/align_fmllr.sh --nj 40 --cmd "$train_cmd" \
#    data/train data/lang_${lexicon_type} exp/tri3 exp/tri3_ali
#fi
#
## make LM and decode
#if [ $stage -le 9 ] && [ ${stop_stage} -ge 9 ]; then
#  num_utts=`cat data/train/text | wc -l`
#  num_valid_utts=$(($num_utts/10))
#  num_train_utts=$(($num_utts - $num_valid_utts)) 
#  
#  mkdir -p data/lm
#  shuf data/train/text > data/lm/text.shuf
#  
#  ./local/train_lm.sh data/dict_sp/lexicon.txt data/lm/text.shuf data/lm
#  ./utils/format_lm.sh data/lang_${lexicon_type} data/lm/lm.gz data/dict_sp/lexicon.txt data/lang_${lexicon_type}
#
#  ./utils/mkgraph.sh data/lang_${lexicon_type} exp/tri3 exp/tri3/graph
#
#  ./steps/decode_fmllr_extra.sh --cmd "$decode_cmd" --nj 30 exp/tri3/graph data/test exp/tri3/decode_test
#fi
#
#exit
#
## To run nnet_pytorch make sure path.sh is setup approrpiately. Refer to 
## https://github.com/m-wiesner/nnet_pytorch/blob/master/librispeech100/path.sh
## for instance
#./local/nnet_pytorch/run-wrn.sh
#./local/nnet_pytorch/decode.sh
#
#
## To run kaldi
#./local/chain/run_tdnn.sh
