#!/bin/bash

speech_data=/export/corpora5 #/PATH/TO/LIBRISPEECH/data

. ./cmd.sh
. ./path.sh

stage=1
subsampling=4
chaindir=exp/chain
model_dirname=wrn
checkpoint=180_220.mdl
acwt=1.0
cw=-1
testsets="tune"
feat_affix="_fbank_64"
decode_nj=80
rescore=false
graphname=graph
lang=data/lang

. ./utils/parse_options.sh

tree=${chaindir}/tree
post_decode_acwt=`echo ${acwt} | awk '{print 10*$1}'`

# Echo Make graph if it does not exist
if [ ! -f ${tree}/${graphname}/HCLG.fst ]; then 
  ./utils/mkgraph.sh --self-loop-scale 1.0 \
    ${lang} ${tree} ${tree}/${graphname}
fi

cw_opts=""
if [ ! -z $cw ]; then
  cw_opts="--chunk-width ${cw}"
fi

for ds in $testsets; do
  [ -f data/${ds}/convs_dup ] && cp data/${ds}/convs_{,no}dup data/${ds}${feat_affix}/ 
  decode_nnet_pytorch.sh ${cw_opts} --min-lmwt 5 \
                         --max-lmwt 20 \
                         --cmd "$decode_cmd" \
                         --checkpoint ${checkpoint} \
                         --acoustic-scale ${acwt} \
                         --post-decode-acwt ${post_decode_acwt} \
                         --nj ${decode_nj} \
                         data/${ds}${feat_affix} exp/${model_dirname} \
                         ${tree}/${graphname} exp/${model_dirname}/decode_${checkpoint}_${graphname}_${acwt}_cw${cw}_${ds}
done

