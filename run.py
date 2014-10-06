#!/usr/bin/env python
# encoding: utf-8

import os
import commands


def get_seed(run):
    run2 = run*run
    seed1 = 41*run+193*run2
    seed2 = 113*run+83*run2
    seed3 = 271*run+71*run2
    return seed1, seed2, seed3


def create_workload(run, load):
    global topo, sim_end, link_rate, spine_num, tor_num, spt
    global port_num, meanFlowSize, workload
    seed1, seed2, seed3 = get_seed(run)
    args = "%d %d %d %d %d %d %d %s %d %d %d %d %s" \
        % (topo, sim_end, link_rate, spine_num, tor_num, spt, port_num,
           load, seed1, seed2, seed3, meanFlowSize, workload)
    cmd = "ns create_workload.tcl %s >create_workload.log" % args
    status = commands.getstatusoutput(cmd)
    if status == 0:
        print "workload creation failed!"


# list args = (run, rm, repflow_num, load, smartRep, DCTCP)
def simulate(args):
    global sim_end, link_rate, link_delay, host_delay, queueSize
    global spt, tor_num, spine_num, port_num, miceflow_thresh
    global workload, meanFlowSize, topo, type

    run = args[0]
    rm = args[1]
    repflow_num = args[2]
    load = args[3]
    DCTCP = args[4]
    smartRep = 0
    if repflow_num > port_num/2-1:
        smartRep = 1

    seed1, seed2, seed3 = get_seed(run)

    output_dir = "/home/wfg/Desktop/stat-%d-%s/stat%d-%s-%d"\
        % (sim_end, type, run, type, sim_end)
    trace_dir = "%s/trace%d-%d-%d-%s"\
        % (output_dir, run, sim_end, rm, type)

    log_dir = "%s/log%d-%d-%d-%s" % (output_dir, run, sim_end, rm, type)
    trace_file = "%s/flow-%d-%s-%d-%d.tr" % (trace_dir, sim_end,
                                             load, repflow_num, rm)
    log_file = "%s/%d-%s-%d-%d.log" % (log_dir, sim_end, load, repflow_num, rm)

    begin = commands.getoutput("date +%s")
    print "Simuation %d-%s-%d-%d starts!\n" % (sim_end, load, repflow_num, rm)
    args = "ns build.tcl %d %d %d %d %d %s %d %d %d %d %d %d %d %s %d %d %d %s %d %d %d %d >%s 2>&1" \
        % (sim_end, link_rate, link_delay, host_delay, queueSize, load,
           spt, tor_num, spine_num, port_num, rm, repflow_num, miceflow_thresh,
           trace_file, seed1, seed2, seed3, workload, meanFlowSize, topo,
           DCTCP, smartRep, log_file)
    commands.getoutput(args)

    end = commands.getoutput("date +%s")
    dur = int(end) - int(begin)

    fd = open(log_file, 'a')
    fd.write("Simulation %d-%s-%d-%d finished in %d secnods\n" % (
        sim_end, load, repflow_num, rm, dur))
    print "Simulation %d-%s-%d-%d finished in %d secnods\n" % (
        sim_end, load, repflow_num, rm, dur)
    fd.close()


def make_dir(args):
    global sim_end, link_rate, link_delay, host_delay, queueSize
    global spt, tor_num, spine_num, port_num, miceflow_thresh
    global workload, meanFlowSize, topo, type

    run = args[0]
    rm = args[1]
    # repflow_num = args[2]
    # load = args[3]
    # DCTCP = args[4]
    # smartRep = 0
    # if repflow_num > port_num/2-1:
    #     smartRep = 1
    # seed1, seed2, seed3 = get_seed(run)

    output_dir = "/home/wfg/Desktop/stat-%d-%s/stat%d-%s-%d"\
        % (sim_end, type, run, type, sim_end)
    cmd = "mkdir -p %s" % output_dir
    commands.getoutput(cmd)

    trace_dir = "%s/trace%d-%d-%d-%s"\
        % (output_dir, run, sim_end, rm, type)
    cmd = "mkdir -p %s" % trace_dir
    commands.getoutput(cmd)

    log_dir = "%s/log%d-%d-%d-%s" % (output_dir, run, sim_end, rm, type)
    cmd = "mkdir -p %s" % log_dir
    commands.getoutput(cmd)


concurrent_process_num = 16
topo = 0
workload_type = 1
# run = [1, 2, 3, 4, 5]
run = [1, 2]
sim_end = 30
load = ["0.1", "0.2", "0.3", "0.4", "0.5", "0.6", "0.7", "0.8"]
# when repflow_num > port_num/2-1, smartRep is enabled
repflow_num = [0, 1]
routing_method = [0, 1]

# 0 indicates tcp-Newreno
# 1 indicates DCTCP
tcp_type = [0]

# workload settings
workload = "cdf/CDF_web-search.tcl"
meanFlowSize = 1138*1460
type = "web"
if workload_type == 1:
    workload = "cdf/CDF_data-mining.tcl"
    meanFlowSize = 5117*1460
    type = "data"
elif workload_type == 2:
    workload = "Pareto"
    meanFlowSize = 100*1460
    type = "pareto"

# for leaf-spine
spt = 16
tor_num = 9
spine_num = 4

# for fat-tree
port_num = 4

link_rate = 10000
link_delay = 0.0000002
host_delay = 0.0000025
queueSize = 225
miceflow_thresh = 100


##############################################
# Workload Creation
##############################################
for r in run:
    for l in load:
        create_workload(r, l)

args = []
for r in run:
    for rm in routing_method:
        for repnum in repflow_num:
            for l in load:
                for tcp in tcp_type:
                    args.append([r, rm, repnum, l, tcp])

# make dirs before any process spawned
for arg in args:
    make_dir(arg)


##############################################
# Run Simulations
##############################################
i = 0
beg = commands.getoutput('date +%s')
while i < len(args):
    pid = 0
    pids = []
    for cnt in range(concurrent_process_num):
        if i >= len(args):
            break
        pid = os.fork()
        if pid == 0:
            simulate(args[i])
            exit(0)
        else:
            pids.append(pid)
        i = i+1
    if pid != 0:
        for pid in pids:
            os.waitpid(pid, 0)

dur = int(commands.getoutput('date +%s'))-int(beg)
print "All simulations done in %d seconds" % dur
