import os
import struct
import argparse
import numpy
import time
import numpy as np

parser = argparse.ArgumentParser()
parser.add_argument("--infile", type=str, default='hsd.xtc', help='input file name')
args = parser.parse_args()

def a32toa16(arr):
    a0 = [a>>16 for a in arr]
    a1 = [a&0xffff for a in arr]
    return np.stack([a0,a1],1).reshape(2*len(arr))

while True:
    print('Opening {}'.format(args.infile))

    with open(args.infile,'r') as f:
        nevent = 0
        print(f'{"Rawhdr":8s} {"Fexhdr":8s} {"Rawminmax":9s} {"Fexminmax":9s} {"Fexcor":23s}')
        for line in f.readlines():
            words = [int(l,16) for l in line.strip().split()]
            nevent += 1
            evhdr  = words[:8]
            rawhdr = words[8:12]
            rawsz  = rawhdr[0]&0x1fffffff
            rawda  = a32toa16(words[12:12+rawsz//2])
            fexhdr = words[12+rawsz//2:16+rawsz//2]
            fexsz  = rawhdr[0]&0x1fffffff
            fexco  = a32toa16(words[16+rawsz//2:18+rawsz//2])
            fexda  = a32toa16(words[18+rawsz//2:])
            print(f'{rawhdr[0]:8x} {fexhdr[0]:8x} {min(rawda):4x},{max(rawda):4x} {min(fexda):4x},{max(fexda):4x}  {fexco}')

    break
