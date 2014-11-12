#!/usr/bin/env python
# encoding: utf-8

import commands

# beg = 6
# end = 10
# for k in range(beg, end+2, 2):
# logfile = 'dat/proto-end-pack1-k%d.log' % k
# cmd = './mt_test %d 0 >%s 2>&1' % (k, logfile)
# commands.getoutput(cmd)

run_beg = 20
step = 5000
run = range(run_beg, 40, 1)
for r in run:
    k = 10
    port_beg = 1025+(r-1)*step
    port_end = port_beg+step
    logfile = 'dat/proto-end-pack1-k%d-%d-%d.log' % (k, port_beg, port_end)
    cmd = './mt_test %d %d %d >%s 2>&1' % (k, port_beg, port_end, logfile)
    commands.getoutput(cmd)
    print "run %d finished" % r
