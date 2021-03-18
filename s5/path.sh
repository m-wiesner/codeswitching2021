export KALDI_ROOT=`pwd`/../../..
[ -f $KALDI_ROOT/tools/env.sh ] && . $KALDI_ROOT/tools/env.sh

export PATH=$PWD/utils/:$KALDI_ROOT/tools/openfst/bin:$KALDI_ROOT/tools/sph2pipe_v2.5/:/export/b09/mwiesner/LORELEI_2019_test/LORELEI/tools/kaldi/tools/srilm/lm/bin/i686-m64:$PWD:$PATH

[ ! -f $KALDI_ROOT/tools/config/common_path.sh ] && echo >&2 "The standard file $KALDI_ROOT/tools/config/common_path.sh is not present -> Exit!" && exit 1
. $KALDI_ROOT/tools/config/common_path.sh

#export ROOT=`pwd`/../../..
#export VENV=${ROOT}/tools/venv_lorelei/bin/activate
export VENV_ROOT=/export/b09/mwiesner/LFMMI_EBM3/nnet_pytorch/tools
. ${VENV_ROOT}/activate_python.sh

export LC_ALL=C
