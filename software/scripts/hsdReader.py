import os
import struct
import argparse
import numpy
import time

from psmon import publish
from psmon.plots import MultiPlot
from psmon.plotting import Histogram,LinePlot
publish.local=True

parser = argparse.ArgumentParser()
parser.add_argument("--infile", type=str, default='/tmp/hsd.dat', help='input file name')
args = parser.parse_args()

line_raw    = LinePlot ('mrl',"Last Raw Wf"   , xlabel='Time(ns)', ylabel='ADU', leg_offset='upper right')
for seg in range(4):
    line_raw.make_plot('ch%02d'%seg )

if not os.path.exists(args.infile):
    os.mkfifo(args.infile)

while True:
    print('Opening {}'.format(args.infile))

    with open(args.infile,'rb') as f:
        nevent = 0
        while True:
            data = f.read(40)
            while len(data)==0:
                print('EOF at event {}.. restart'.format(nevent))
                time.sleep(1)
                data = f.read(40)
            nevent += 1
            info   = struct.unpack('10I',data)
            evsize = info[0]
            print('Read event size {}'.format(evsize))
            evsize -= 40
            streams = (info[8]>>20)&0xff
            line_raw.clear()
            lraw = {}
            while evsize>0:
                hdr      = struct.unpack('4I',f.read(16))
                stream   = (hdr[1]>>24)&0xff
                nsamples = hdr[0]&0x3fffffff
                vsamples = numpy.fromfile(f,dtype=numpy.uint16,count=nsamples)
                print('hdr {}  stream {}  samples {} [{}]'.format(hdr,stream,nsamples,vsamples[:4]))
                evsize  -= 32+2*nsamples
                xscale   = 0.125e3/156.25 if stream < 4 else 0.03125e3/156.25
                xaxis    = numpy.linspace(0.,nsamples*xscale,nsamples)
                lraw[stream] = (xaxis.copy(),vsamples.copy())
                line_raw .add('ch%02d'%stream, *lraw[stream])
            line_raw.publish()
