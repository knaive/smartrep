source lib/tcp-pair.tcl
source lib/workload.tcl
source lib/fat-tree.tcl
source lib/leaf-spine.tcl
source lib/smartRep.tcl

if {$argc != 22} {
    puts "wrong number of arguments $argc"
    exit 0
}

set sim_end [lindex $argv 0]
set link_rate [lindex $argv 1]
set mean_link_delay [lindex $argv 2]
set host_delay [lindex $argv 3]
set queueSize [lindex $argv 4]
set load [lindex $argv 5]

#### topology
set spt [lindex $argv 6]
set tor_num [lindex $argv 7]
set spine_num [lindex $argv 8]
set k [lindex $argv 9]

#### Routing method
set routing_method [lindex $argv 10]

#### Repflow settings
set repflow_maxnum [lindex $argv 11]
set miceflow_thresh [lindex $argv 12]
set flow_stat [lindex $argv 13]
set seed1 [lindex $argv 14]
set seed2 [lindex $argv 15]
set seed3 [lindex $argv 16]

set cdf_file [lindex $argv 17]
set meanFlowSize [lindex $argv 18]
set topo [lindex $argv 19]
set DCTCP [lindex $argv 20]
set smartRep [lindex $argv 21]

#### Packet size is in bytes.
set pktSize 1460
set enable_flow_traces 0

puts "Simulation input:" 
if {$topo} { 
    puts "topology: leaf-spine with $spine_num spines, $tor_num top-of-racks, and $spt servers in each tor"
} else {
    puts "topology: fat-tree with k = $k"
}
puts "sim_end $sim_end"
puts "repflow max number: $repflow_maxnum"
puts "link_rate $link_rate Mbps"
puts "link_delay $mean_link_delay sec"
puts "RTT  [expr $mean_link_delay * 2.0 * 6] sec"
puts "host_delay $host_delay sec"
puts "queue size $queueSize pkts"
puts "load $load"
puts "pktSize(payload) $pktSize Bytes"
puts "pktSize(include header) [expr $pktSize + 40] Bytes"
puts "CDF file: $cdf_file"
puts "seed1: $seed1"
puts "seed2: $seed2"
puts "seed3: $seed3"
puts "meanFlowSize : $meanFlowSize"
puts "DCTCP: $DCTCP"
puts "smartRep: $smartRep"

################# Transport Options ####################

if {$DCTCP == 0 } {
    set switchAlg DropTail

    # ACK packet size
    Agent/TCP set packetSize_ $pktSize
    Agent/TCP/FullTcp set segsize_ $pktSize
    Agent/TCP/FullTcp set spa_thresh_ 0

    # cong avoid algorithm(1:standard)
    Agent/TCP set windowOption_ 1

    # timer granulatiry in sec
    Agent/TCP set tcpTick_ 0.0000001

    # bound on RTO
    Agent/TCP set maxrto_ 0.001
    Agent/TCP set minrto_ 0.0002

    Agent/TCP/FullTcp set nodelay_ true; # disable Nagle
    Agent/TCP/FullTcp set interval_ 0.000006

    # max bound on window size
    Agent/TCP set window_ 1000000

    # initial/reset value of cwnd
    Agent/TCP set windowInit_ 12

    if {$queueSize > 12} {
        Agent/TCP set maxcwnd_ [expr $queueSize - 1];
    } else {
        Agent/TCP set maxcwnd_ 12;
    }
    set myAgent "Agent/TCP/FullTcp/Newreno";

################# Switch Options ######################

    Queue set limit_ $queueSize
    Queue/DropTail set queue_in_bytes_ false
    Queue/DropTail set mean_pktsize_ [expr $pktSize+40]

} else {
    set myAgent "Agent/TCP/FullTcp/Newreno";
    set switchAlg RED
    Agent/TCP set dctcp_ true
    Agent/TCP set dctcp_g_ 0.0625
    Agent/TCP set ecn_ 1
    Agent/TCP set old_ecn_ 1
    Agent/TCP set packetSize_ $pktSize
    Agent/TCP/FullTcp set segsize_ $pktSize
    Agent/TCP set window_ 1000000
    Agent/TCP set slow_start_restart_ false
    Agent/TCP set tcpTick_ 0.0000001
    Agent/TCP set minrto_ 0.0002 ; # minRTO = 200ms
    Agent/TCP set windowOption_ 0

    Agent/TCP/FullTcp set segsperack_ 1
    Agent/TCP/FullTcp set spa_thresh_ 3000;
    Agent/TCP/FullTcp set interval_ 0.04 ; #delayed ACK interval = 40ms

    Queue set limit_ 1000

    Queue/RED set bytes_ false
    Queue/RED set queue_in_bytes_ true
    Queue/RED set mean_pktsize_ $pktSize
    Queue/RED set setbit_ true
    Queue/RED set gentle_ false
    Queue/RED set q_weight_ 1.0
    Queue/RED set mark_p_ 1.0
    Queue/RED set thresh_ 65
    Queue/RED set maxthresh_ 65

    DelayLink set avoidReordering_ true
}

################## Scheduler and Traces ###############
#
set start_time [clock seconds]
set ns [new Simulator]
if {$enable_flow_traces} {
    set all_traces [open flow.tr w]
    # trace-all command must appear immediately after creating scheduler
    $ns trace-all $all_traces
}


################ Routing Strategy###########################

Agent/rtProto/DV set advertInterval [expr 2*$sim_end]
Node set multiPath_ 1
if {$topo} {
    set equalpath_num $spine_num
    set collision_chances 1
} else {
    set equalpath_num [expr $k/2]
    set collision_chances 1
}
switch $routing_method {
        0 {
                Classifier/MultiPath set perflow_ 1
                Classifier/MultiPath set total_chances_ $equalpath_num
                Classifier/MultiPath set collision_chances_ $collision_chances
                $ns rtproto DV
                puts "Routing method : per-flow multipath with collision in [expr 100.0 * $collision_chances/$equalpath_num]% of time\n"
        }
        1 {
                Classifier/MultiPath set perflow_ 1
                Classifier/MultiPath set total_chances_ $equalpath_num
                Classifier/MultiPath set collision_chances_ 0
                $ns rtproto DV
                puts "Routing method : per-flow multipath without collision\n"
        }
        2 {
                puts "Static hash based routing\n" 
        }
        3 {
                Classifier/MultiPath set perflow_ 0
                $ns rtproto DV
                puts "Routing method : per-packet multipath\n"
        }
        default {
                puts "Wrong routing method!"
                exit 0
        }
} 

##############################  Workload Generation    #########################
#
# 0 for fat-tree
# 1 for Leaf-spine
if {$topo} {
    set host_num [expr $tor_num*$spt]
    set max_goodput [expr $link_rate*$spine_num*$tor_num]
} else {
    set host_num [expr $k*$k*$k/4]
    set max_goodput [expr $link_rate*$host_num]
}
set avg_inter_arrival [expr ($meanFlowSize*8.0)/($max_goodput*1000000*$load)]
puts "Arrival at the heaviest load : Poisson with inter-arrival [expr $avg_inter_arrival*$load * 1000000] us\n"
puts "Arrival : Poisson with inter-arrival [expr $avg_inter_arrival * 1000000] us\n"

# initialization
for {set i 0} {$i < $sim_end} {incr i} {
    set snode($i) 0
    set dnode($i) 0
    set interval($i) 0
    set flowsize($i) 0
}
for {set i 1} {$i <= $miceflow_thresh} {incr i} {
    set repNum($i) 0
}
if {[string compare $cdf_file "cdf/CDF_web-search.tcl"] == 0} {
    set repNumFile "cdf/repnum-web-[expr $equalpath_num-1]-0.1.dat"
} elseif {[string compare $cdf_file "cdf/CDF_data-mining.tcl"] == 0} {
    set repNumFile "cdf/repnum-data-[expr $equalpath_num-1]-0.1.dat"
}
set load_dir "rndnum"
set cs_pair_file  "$load_dir/cs_pair-$sim_end-$host_num-$seed1.txt"
set inter_size_file "$load_dir/inter_size-$sim_end-$load-$link_rate-$seed2-$seed3.txt"
if {![file exists $cs_pair_file] || ![file exists $inter_size_file]} {
    puts "workload not created!"
    exit 0
}
load_cs_pair $cs_pair_file snode dnode
load_interval_size $inter_size_file interval flowsize
if {$smartRep == 1} {
    load_repNum $repNumFile repNum
}
# debug
puts "$repNumFile"
for {set i 1} {$i <= $miceflow_thresh} {incr i} {
    puts "$repNum($i)"
}


puts "Workload generation done\n"; flush stdout

################### tcp connection setup ###########################################
puts "Setting up connections ...\n"; flush stdout

set flow_log [open $flow_stat w]
set num_of_live_flows 0
set num_of_dead_flows 0
set origin_flow_num 0
set flow_total_num 0

if {$topo} {
    set leaf [new Leaf-spine]
    $leaf setup $ns $tor_num $spt $spine_num $link_rate $link_rate $host_delay $mean_link_delay 
    $leaf schedule $sim_end snode dnode flowsize interval
} else {
    set ft [new Fat-tree]
    $ft setup $ns $k $link_rate $mean_link_delay $host_delay $switchAlg $smartRep
    $ft schedule $sim_end snode dnode flowsize interval
}

puts "Initial agent creation done\n";flush stdout
puts "NS RUN!\n"
puts "********************************************\n"

$ns run
