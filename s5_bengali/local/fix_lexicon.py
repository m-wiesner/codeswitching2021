import argparse
import unicodedata
import random
import re
import subprocess
try:
    import epitran
except ImportError:
    from pip._internal import main as pip
    pip(['install', 'epitran'])
    import epitran
import os
import unicodecsv as csv


def _load_arpa2ipa():
    path = os.path.join(os.path.dirname(epitran.__file__), 'data/arpabet.csv')
    pairs = {}
    with open(path, 'rb') as f:
        reader = csv.reader(f, encoding='utf-8')
        next(reader)
        for arpa, ipa in reader:
            pairs[arpa.upper()] = ipa
    return pairs


def _load_lex(f):
    lex = {}
    for l in f:
        try:
            word, pron = l.strip().split(None, 1)
        except:
            import pdb; pdb.set_trace()
            print()
        if word not in lex:
            lex[word] = []
        lex[word].append(pron)
    return lex


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("lex_orig")
    parser.add_argument("lex_supp")
    parser.add_argument("g2p")
    parser.add_argument("--use-lang-tags", action='store_true')
    args = parser.parse_args()

    with open(args.lex_orig, 'r', encoding='utf-8') as f1, open(args.lex_supp, 'r', encoding='utf-8') as f2:
        lex_orig = _load_lex(f1)
        lex_supp = _load_lex(f2)

    arpa2ipa = _load_arpa2ipa()

    bengali = re.compile(r'([\u0980-\u09FF]\s*)+')
    xs = epitran.xsampa.XSampa()
    arpa2xs = {i:xs.ipa2xs(v) for i, v in arpa2ipa.items()} 
    for w, prons in lex_orig.items():
        for pron in prons:
            new_pron = ''
            w_start = 0
            for match in bengali.finditer(pron):
                w_start_, w_end = match.span()
                bengali_word = pron[w_start_:w_end].replace(' ', '')
                if bengali_word in lex_supp:
                    pron_idx = int((random.random() - 1e-10) * len(prons))   
                    bengali_pron = lex_supp[bengali_word][pron_idx]
                else:
                    cmd="phonetisaurus-g2pfst --model={} --word={} --nbest=1".format(args.g2p, bengali_word)
                    g2p_out = subprocess.check_output(cmd.split(), stderr=subprocess.DEVNULL)
                    bengali_pron = g2p_out.decode().split('\t')[2]
                bengali_pron_xsampa = u' '.join(map(xs.ipa2xs, bengali_pron.split()))
                if args.use_lang_tags:
                    bengali_pron_xsampa = u' '.join([i + "_L2" for i in bengali_pron_xsampa.split()])
                pron_xsampa = u' '.join([arpa2xs.get(i, i) for i in pron[w_start:w_start_].split()])
                new_pron += pron_xsampa + ' ' + bengali_pron_xsampa + ' ' 
                w_start = w_end
            
            pron_xsampa = u' '.join([arpa2xs.get(i, i) for i in pron[w_start:len(pron)].split()])
            new_pron += pron_xsampa
            if new_pron.strip() == "":
                new_pron = "SPN"
            print(w, new_pron) 
             

if __name__ == "__main__":
    main()
