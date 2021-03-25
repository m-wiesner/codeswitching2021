#!/bin/bash

bengali_dict=https://raw.githubusercontent.com/navana-tech/baseline_recipe_is21s_indic_asr_challenge/master/is21-subtask2-kaldi/bengali_baseline/corpus/lang
hindi_dict=https://raw.githubusercontent.com/navana-tech/baseline_recipe_is21s_indic_asr_challenge/master/is21-subtask2-kaldi/hindi_baseline/corpus/lang

wget ${hindi_dict}/lexicon.txt -O data/dict/lexicon.txt
wget ${hindi_dict}/nonsilence_phones.txt -O data/dict/nonsilence_phones.txt
wget ${hindi_dict}/silence_phones.txt -O data/dict/silence_phones.txt
wget ${hindi_dict}/optional_silence.txt -O data/dict/optional_silence.txt
