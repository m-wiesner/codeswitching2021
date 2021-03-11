#!/bin/bash

speech_data=/export/corpora5 #/PATH/TO/LIBRISPEECH/data

. ./cmd.sh
. ./path.sh

stage=1
subsampling=4
chaindir=exp/chain
langname=lang
model_dirname=wrn
checkpoint=253_303.mdl
acwt=1.0
cw=140
testsets="test"
feat_affix="_fbank_64"
decode_nj=80
rescore=false

. ./utils/parse_options.sh

tree=${chaindir}/tree
post_decode_acwt=`echo ${acwt} | awk '{print 10*$1}'`

# Echo Make graph if it does not exist
if [ ! -f ${tree}/graph/HCLG.fst ]; then 
  ./utils/mkgraph.sh --self-loop-scale 1.0 \
    data/${langname} ${tree} ${tree}/graph_${langname}
fi

cw_opts=""
if [ ! -z $cw ]; then
  cw_opts="--chunk-width ${cw}"
fi

for ds in $testsets; do 
  decode_nnet_pytorch.sh ${cw_opts} --min-lmwt 6 \
                         --max-lmwt 18 \
                         --cmd "$decode_cmd" \
                         --checkpoint ${checkpoint} \
                         --acoustic-scale ${acwt} \
                         --post-decode-acwt ${post_decode_acwt} \
                         --nj ${decode_nj} \
                         data/${ds}${feat_affix} exp/${model_dirname} \
                         ${tree}/graph_${langname} exp/${model_dirname}/decode_${checkpoint}_graph_${langname}_${acwt}_cw${cw}_${ds}
  
done

