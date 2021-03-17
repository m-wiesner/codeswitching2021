#!/usr/bin/env python3
# -*- coding: utf-8 -*-

""" This script creates paragraph level text file. It reads 
    the line level text file and combines them to get
    paragraph level file.
  Eg. local/combine_line_txt_to_paragraph.py
  Eg. Input:  103085_w5Jyq3XMbb3WwiKQ_0002 यहाँ हम अपने ऑपरेटिंग सिस्टम के रूप में gnu/लिनक्स और लिबर ऑफिस वर्जन 334 का उपयोग कर
              103085_w5Jyq3XMbb3WwiKQ_0003 चलिए अपनी प्रस्तुति sample impress open करते हैं जिसे पिछले tutorial में
              103085_w5Jyq3XMbb3WwiKQ_0004 चलिए देखते हैं कि screen पर क्या क्या है
      Output: 103085_w5Jyq3XMbb3WwiKQ याँ हम अपने ऑपरेिं ... चलिए देखते हैं कि screen पर क्या क्या
"""

import argparse
import os
import io
import sys
### main ###
infile = io.TextIOWrapper(sys.stdin.buffer, encoding='utf-8')
output = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

paragraph_txt_dict = dict()
for line in infile:
    line_vect = line.strip().split(' ')
    uttid = line_vect[0]
    sequence_id = int(uttid.split('_')[-1])
    recoid = uttid.split('_')[1]
    #paragraph_id = "_".join(uttid.split('_')[0:-1])
    utterance_text = " ".join(line_vect[1:])
    if recoid not in paragraph_txt_dict:
        paragraph_txt_dict[recoid] = dict()
    paragraph_txt_dict[recoid][sequence_id] = utterance_text
    #if paragraph_id not in paragraph_txt_dict.keys():
    #    paragraph_txt_dict[paragraph_id] = dict()
    #paragraph_txt_dict[paragraph_id][sequence_id] = utterance_text


para_txt_dict = dict()
for para_id in sorted(paragraph_txt_dict.keys()):
    para_txt = ""
    for line_id in sorted(paragraph_txt_dict[para_id]):
        text = paragraph_txt_dict[para_id][line_id]
        para_txt = para_txt + " " + text
    para_txt_dict[para_id] = para_txt
    utt_id = str(para_id).zfill(6)
    output.write(utt_id + ' ' + para_txt + '\n')
