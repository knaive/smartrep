#!/usr/bin/env python
# encoding: utf-8

import commands

beg = 6
end = 10
for k in range(beg, end+2, 2):
    logfile = 'dat/proto-end-pack1-k%d.log' % k
    cmd = './mt_test %d 0 >%s 2>&1' % (k, logfile)
    commands.getoutput(cmd)
