#!/bin/bash

# This is based almost entirely on the Kaldi librispeech recipe
# Change this location to somewhere where you want to put the data.
# This recipe ASSUMES YOU HAVE DOWNLOADED the Librispeech data

. ./cmd.sh
. ./path.sh

stage=0
subsampling=4
traindir=data/train
testdir=data/test
feat_affix=_fbank_64
alidir=exp/tri3_ali
chaindir=exp/chain
num_leaves=3500
model_dirname=wrn
width=10
depth=28
l2=0.0001
xent=0.1
lr=0.0002
leaky_hmm=0.1
decay=1e-05
weight_decay=1e-07
warmup=15000
batches_per_epoch=250
num_epochs=303
nj_init=2
nj_final=6
perturb="[('time_mask', {'width': 10, 'max_drop_percent': 0.5}), ('freq_mask', {'width': 10, 'holes': 5}), ('gauss', {'std': 0.1})]"
chunkwidth=220
min_chunkwidth=60
random_cw=True
left_context=10
right_context=5
batchsize=24
delay_updates=1
grad_thresh=32.0
seed=0
resume=
num_split=80 # number of splits for memory-mapped data for training
average=true
. ./utils/parse_options.sh

set -euo pipefail

tree=${chaindir}/tree
targets=${traindir}${feat_affix}/pdfid.${subsampling}.tgt
trainname=`basename ${traindir}`

if [ $stage -le 0 ]; then
  for d in ${traindir} ${testdir}; do
    ./utils/copy_data_dir.sh ${d} ${d}${feat_affix}
    ./steps/make_fbank.sh --cmd "$train_cmd" --nj 32 ${d}${feat_affix}
    ./utils/fix_data_dir.sh ${d}${feat_affix}
    ./steps/compute_cmvn_stats.sh ${d}${feat_affix}
    ./utils/fix_data_dir.sh ${d}${feat_affix}
  done

  prepare_unlabeled_tgt.py --subsample ${subsampling} \
    ${testdir}${feat_affix}/utt2num_frames > ${testdir}/pdfid.${subsampling}.tgt
fi

# Den.fst and tgt creation
if [ $stage -le 1 ]; then
  echo "Creating Chain Topology, Denominator Graph, and nnet Targets ..."
  lang=data/lang_chain
  cp -r data/lang $lang
  silphonelist=$(cat $lang/phones/silence.csl) || exit 1;
  nonsilphonelist=$(cat $lang/phones/nonsilence.csl) || exit 1;
  # Use our special topology... note that later on may have to tune this
  # topology.
  steps/nnet3/chain/gen_topo.py $nonsilphonelist $silphonelist >$lang/topo

  steps/nnet3/chain/build_tree.sh \
    --frame-subsampling-factor ${subsampling} \
    --context-opts "--context-width=2 --central-position=1" \
    --cmd "$train_cmd" ${num_leaves} ${traindir} \
    $lang $alidir ${tree}

  ali-to-phones ${tree}/final.mdl ark:"gunzip -c ${tree}/ali.*.gz |" ark:- |\
    chain-est-phone-lm --num-extra-lm-states=2000 ark:- ${chaindir}/phone_lm.fst

  chain-make-den-fst ${tree}/tree ${tree}/final.mdl \
    ${chaindir}/phone_lm.fst ${chaindir}/den.fst ${chaindir}/normalization.fst

  ali-to-pdf ${tree}/final.mdl ark:"gunzip -c ${tree}/ali.*.gz |" ark,t:${targets}
fi

# Distribute memmapped features
if [ $stage -le 2 ]; then
  echo "Dumping memory mapped features ..."
  for d in ${traindir}${feat_affix} ${testdir}${feat_affix}; do
    split_memmap_data.sh ${d} ${d}/pdfid.${subsampling}.tgt ${num_split} 
  done
fi

# Training
if [ $stage -le 3 ]; then
  resume_opts=
  if [ ! -z $resume ]; then
    resume_opts="--resume ${resume}"
  fi 
  num_pdfs=$(tree-info ${tree}/tree | grep 'num-pdfs' | cut -d' ' -f2)
  train_script="train.py ${resume_opts} \
    --gpu \
    --expdir `dirname ${chaindir}`/${model_dirname} \
    --objective LFMMI \
    --denom-graph ${chaindir}/den.fst \
    --leaky-hmm ${leaky_hmm} \
    --num-targets ${num_pdfs} \
    --subsample ${subsampling} \
    --model ChainWideResnet \
    --depth ${depth} \
    --width ${width} \
    --warmup ${warmup} \
    --decay ${decay} \
    --weight-decay ${weight_decay} \
    --lr ${lr} \
    --optim adam \
    --l2-reg ${l2} \
    --xent-reg ${xent} \
    --batches-per-epoch ${batches_per_epoch} \
    --num-epochs 1 \
    --delay-updates ${delay_updates} \
    --grad-thresh ${grad_thresh} \
    --datasets \"[ \
        {\
     'data': '${traindir}${feat_affix}', \
     'tgt': '${targets}', \
     'batchsize': ${batchsize}, \
     'chunk_width': ${chunkwidth}, 'min_chunk_width': ${min_chunkwidth}, \
     'left_context': ${left_context}, 'right_context': ${right_context}, 'num_repeats': 1, \
     'mean_norm': True, 'var_norm': False, 'random_cw': ${random_cw}, \
     'perturb_type': '''${perturb}'''\
       },\
     ]\"\
     "
 
  train_cmd="utils/retry.pl utils/queue.pl --mem 4G --gpu 1 --config conf/gpu.conf"

  train_async_parallel.sh ${resume_opts} \
    --cmd "$train_cmd" \
    --nj-init ${nj_init} \
    --nj-final ${nj_final} \
    --num-epochs ${num_epochs} \
    --seed ${seed} \
    "${train_script}" `dirname ${chaindir}`/${model_dirname}
fi

# Average the last 50 epochs
if [ $stage -le 4 ]; then
  if $average; then
    feat_dim=$(feat-to-dim scp:${traindir}/feats.scp -)
    start_avg=$((num_epochs - 50))
    average_models.py `dirname ${chaindir}`/${model_dirname} ${feat_dim} ${start_avg} ${num_epochs}
  fi
fi
