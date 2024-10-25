#
#  Generate input data for baseline correction simulation and output for validation
#
#  Separate biased baseline and smooth signal
#  Assert only baseline during correction accumulation

import random
import numpy

# naccums = 12 => 2**9 (512) rows
nsamples = 3200   # 80 rows of 40

baseline = [0x7ff,0x800,0x801,0x802]
#signal   = [-0x04,0x20,0x20,-0x04]
signal   = [-0x040,0x200,0x200,-0x040]

baserow = []
for i in range(10):
    baserow.extend(baseline)

signrow = signal+[0]*36
qrow = numpy.array(baserow) + numpy.array(signrow)

print(f'baserow {baserow}')
print(f'signrow {signrow}')
print(f'qrow    {qrow}')

x = []
t = []
for i in range(540):
    x.extend(baserow)
    t.append(0)

for i in range(4):
    x.extend(qrow.tolist())
t.extend([1,0,0,0])

for i in range(3):
    x.extend(baserow)
    t.append(0)

for i in range(6):
    x.extend(qrow.tolist())
    t.append(0)

for i in range(6):
    x.extend(baserow)
    t.append(0)

for i in range(1):
    x.extend(qrow.tolist())
    t.append(0)
    
x = numpy.array(x)
         
row = 0
f = open('adcin','w')

def writeline(x,t):
    global row
    y = x[40*row:40*(row+1)]
    s = ' '
    s += numpy.array2string(y,max_line_width=1024, formatter={'int':lambda z: '%03x'%z})[1:-1]
    s += f' {t[row]}\n'
    f.write(s)
    row += 1
    if row*40 >= len(x):
        row = 0

for i in range(1000):
    writeline(x,t)
         
