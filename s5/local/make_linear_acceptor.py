#!/usr/bin/env python3

# 2020 Dongji Gao
# Apache 2.0

import sys
import argparse

def get_args():
    parser = argparse.ArgumentParser(description="""This script creates the
        text form of a linear acceptor which will be used for segmenting long
        utterances.""")

    parser.add_argument("--dis-id", type=int, help="""integer id of disambig symbol, may need for determinization""")
    parser.add_argument("--eps-id", type=int, default=0, help="""integer id of eps""")
    parser.add_argument("--oov-id", type=int, help="""integer id of oov (<unk>) symbol, will add this function in the future""")
    
    parser.add_argument("--allow-insertion", action='store_true')
    parser.add_argument("--insertion-str", type=str, default="")
    parser.add_argument("--subword-str", type=str, default="")
    parser.add_argument("--insertion-cost", type=float, default=1.0)

    parser.add_argument("--allow-skip", action='store_true')
    parser.add_argument("--skip-cost", type=int, default=5)

    parser.add_argument("--allow-deletion", action='store_true')
    parser.add_argument("--deletion-limit", type=int, default=1)
    parser.add_argument("--initial-deletion-cost", type=float, default=1.0)
    parser.add_argument("--deletion-increase", type=float, default=1.0)

    parser.add_argument("--final-interval", type=int, default=3)
    parser.add_argument("--begin-cost", type=int, default=0, help="""penalty at the 
        beginning of acceptor to avoid matching""")
    parser.add_argument("--begin-cost-decay", type=float, default=1.5, help="""Decay of 
        begining cost to avoid always match from the beginning of the acceptor""")

    args= parser.parse_args()
    return args

def print_arc(src, dest, input, output, cost):
    print("{}\t{}\t{}\t{}\t{}".format(src, dest, input, output, cost))

def check_args(args):
    insertion_list = []
    subword_list = []
    if args.allow_insertion:
        if len(args.insertion_str) == 0:
            insertion_list=[args.oov_id]
        else:
            insertion_list = args.insertion_str.split()

        subword_list = []
        if len(args.subword_str) > 0:
            subword_list = args.subword_str.split()
    return insertion_list, subword_list

def process_one_line(args, line):
    insertion_list, subword_list = check_args(args)

    start_state = 0
    skip_state = 1
    final_state = 2

    state_list = [start_state]

    cur_state = start_state
    next_state = 3

    cost = args.begin_cost

    state_count = 0

    line_split = line.split()
    utt_id = line_split[0]
    print(utt_id)

    if args.allow_insertion:
        for insertion_word in insertion_list:
            print_arc(start_state, start_state, insertion_word, insertion_word, args.insertion_cost)
        
    # special case
    if len(line_split) == 1:
        print("{}\t{}".format(start_state, 0))
        print("")
    else:
        for word in line_split[1:-1]:
            # try to recover oov word
#            if word == str(args.oov_id):
#                for subword in subword_list:
#                    print_arc(cur_state, cur_state, subword, subword, 0)
#            else:
            print_arc(cur_state, next_state, word, word, cost)
            # linear deletion
            #print_arc(cur_state, next_state, args.dis_id, args.eps_id, 2) 
            state_list.append(next_state)

            if args.allow_insertion:
                # add insertion loop
                for insertion_word in insertion_list:
                    print_arc(next_state, next_state, insertion_word, insertion_word, args.insertion_cost)
            cur_state = next_state
            next_state += 1
    
            cost //= args.begin_cost_decay
    
        # deal with final state
        if args.allow_insertion:
            for insertion_word in insertion_list:
                print_arc(final_state, final_state, insertion_word, insertion_word, args.insertion_cost)
         
        word = line_split[-1]
        print_arc(cur_state, final_state, word, word, 0)
        state_list.append(final_state)
        assert(len(state_list) >= 2)
    
        # add final state
#        for index in range(1, len(state_list)-1):
#            if index % args.final_interval == 0:
#                state = state_list[index]
#                print("{}\t{}".format(state, 0))
    
        # add skip operation
        if args.allow_skip:
            for state in state_list:
                print_arc(state, skip_state, args.dis_id, args.eps_id, args.skip_cost * 3)
                print_arc(skip_state, state, args.dis_id, args.eps_id, 0)
    
#        if args.allow_deletion:
#            for cur_index in range(len(state_list) - 1):
#                from_state = state_list[cur_index]
#                deletion_cost = args.initial_deletion_cost
#                max_linear_index = cur_index + args.deletion_limit
#    
#                for tmp_index in range(cur_index+1, min(max_linear_index+1, len(state_list))):
#                    to_state = state_list[tmp_index]
#                    print_arc(from_state, to_state, args.dis_id, args.eps_id, deletion_cost)
#                    deletion_cost += args.deletion_increase
#    
#                if max_linear_index < len(state_list) - 1:
#                    for tmp_index in range(max_linear_index+1, len(state_list)):
#                        to_state = state_list[tmp_index]
#                        print_arc(from_state, to_state, args.dis_id, args.eps_id, deletion_cost)
        if args.allow_deletion:
            for state in state_list[1:-1]:
                print_arc(start_state, state, args.dis_id, args.eps_id, 0)
                print_arc(state, final_state, args.dis_id, args.eps_id, 0)
#            nl_state_list = []
#            deletion_limit = args.deletion_limit
#            num_nl_state = len(state_list) - deletion_limit
#            if num_nl_state > 0:
#                for i in range(num_nl_state):
#                    cur_state = next_state
#                    next_state += 1
#                    print_arc(cur_state, next_state, args.dis_id, args.eps_id, 0)
#                    nl_state_list.append(cur_state)
#                nl_state_list.append(next_state)
#
#            for cur_index in range(len(state_list) - 1):
#                from_state = state_list[cur_index]
#
#                if cur_index < num_nl_state:
#                    nl_state = nl_state_list[cur_index]
#                    to_state = state_list[cur_index + deletion_limit]
#                    print_arc(from_state, nl_state, args.dis_id, args.eps_id, deletion_limit)
#                    print_arc(nl_state, to_state, args.dis_id, args.eps_id, 0)
#
#                deletion_cost = 1
#                for tmp_index in range(cur_index+1, min(len(state_list), cur_index + deletion_limit)):
#                    to_state = state_list[tmp_index]
#                    print_arc(from_state, to_state, args.dis_id, args.eps_id, deletion_cost)
#                    deletion_cost += 1

        # final weight
        print("{}\t{}".format(final_state, 0))
        print("")

def process_lines(args):
    lines_processed = 0
    while True:
        line = sys.stdin.readline()
        if not line:
            break
        process_one_line(args, line)
        lines_processed += 1
        
    return  lines_processed

def main():
    args = get_args()
    lines_processed = process_lines(args)
    
if __name__ == "__main__":
    main()
