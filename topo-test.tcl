source lib/tcp-pair.tcl
source lib/workload.tcl
source lib/fat-tree.tcl
source lib/leaf-spine.tcl

set sim_end 2
set link_rate 10000
set mean_link_delay 0.0000002
set host_delay 0.0000025
set queueSize 225
set load 1.0

#### topology
set topology_spt 16
set topology_tors 9
set topology_spines 2

set k 4

#### Routing method
set routing_method 3

#### Repflow settings
set eleph_num 0
set repflow_maxnum 0
set miceflow_thresh 100
set seed1 777
set seed2 10234
set seed3 137

set trace_file "flow-duration.tr"
set cdf_file "cdf/CDF_vl2.tcl"
set meanFlowSize [expr 1138*1460]
set topo 0

#### Packet size is in bytes.
set pktSize 1460

puts "Simulation input:" 
if {$topo} {
    puts "topology: leaf-spine with $spine_num spines, $tor_num top-of-racks, and $spt servers in each tor"
} else {
    puts "topology: fat-tree with k = $k"
}
puts "sim_end $sim_end"
puts "link_rate $link_rate Mbps"
puts "link_delay $mean_link_delay sec"
puts "RTT  [expr $mean_link_delay * 2.0 * 6] sec"
puts "host_delay $host_delay sec"
puts "queue size $queueSize pkts"
puts "load $load"
puts "pktSize(payload) $pktSize Bytes"
puts "pktSize(include header) [expr $pktSize + 40] Bytes"
puts "CDF type : $cdf_file"
puts "meanFlowSize : $meanFlowSize"

################# Transport Options ####################

# ACK packet size
Agent/TCP set packetSize_ $pktSize
Agent/TCP/FullTcp set segsize_ $pktSize
Agent/TCP/FullTcp set spa_thresh_ 0

# cong avoid algorithm(1:standard)
Agent/TCP set windowOption_ 1

# timer granulatiry in sec
Agent/TCP set tcpTick_ 0.000001

# bound on RTO
Agent/TCP set maxrto_ 2

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

################## Scheduler and Traces ###############
#
set start_time [clock seconds]
set ns [new Simulator]
set all_traces [open flow.tr w]
# trace-all command must appear immediately after creating scheduler
$ns trace-all $all_traces

################ Routing Strategy###########################

Agent/rtProto/DV set advertInterval [expr 2*$sim_end]
Node set multiPath_ 1
switch $routing_method {
        0 {
                Classifier/MultiPath set perflow_ 1
                Classifier/MultiPath set total_chances_ 4
                Classifier/MultiPath set collision_chances_ 4
                $ns rtproto DV
                puts "Routing method : per-flow multipath with collision\n"
        }
        1 {
                set total_chances 4
                set collision_chances 2
                Classifier/MultiPath set perflow_ 1
                Classifier/MultiPath set total_chances_ $total_chances
                Classifier/MultiPath set collision_chances_ $collision_chances
                $ns rtproto DV
                puts "Routing method : per-flow multipath with collision in [expr 100.0 * $collision_chances/$total_chances]% of time\n"
        }
        2 {
                Classifier/MultiPath set perflow_ 1
                Classifier/MultiPath set total_chances_ 4
                Classifier/MultiPath set collision_chances_ 0
                $ns rtproto DV
                puts "Routing method : per-flow multipath without collision\n"
        }
        3 {
                puts "Static hash based routing\n" 
        }
        4 {
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

set load_dir "rndnum"
if {![file exists $load_dir]} { file mkdir $load_dir }
set cs_pair_file  "$load_dir/cs_pair-$sim_end-$host_num-$seed1.txt"
set inter_size_file "$load_dir/inter_size-$sim_end-$load-$link_rate-$seed2-$seed3.txt"

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

if {![file exists $cs_pair_file]} {
    create_cs_pair $host_num $sim_end $cs_pair_file $seed1
}
if {![file exists $inter_size_file]} {
    create_interval_size $sim_end $avg_inter_arrival $inter_size_file $cdf_file $seed2 $seed3
}
load_cs_pair $cs_pair_file snode dnode
load_interval_size $inter_size_file interval flowsize

puts "Workload generation done\n"; flush stdout

################### tcp connection setup ###########################################
Fat-tree instproc rtt {ct src dst flowsize} {
        $self instvar s
        set cs_pair [new CS_pair]
        $cs_pair setup $src $dst
        $cs_pair create_flow s $ct $flowsize
}
Leaf-spine instproc rtt {ct src dst flowsize} {
        $self instvar s
        set cs_pair [new CS_pair]
        $cs_pair setup $src $dst
        $cs_pair create_flow s $ct $flowsize
}
puts "Setting up connections ...\n"; flush stdout

set flow_log [open $trace_file w]
set num_of_live_flows 0
set num_of_dead_flows 0
set flow_total_num 0

if {$topo} {
    set leaf [new Leaf-spine]
    $leaf setup $ns $tor_num $spt $spine_num $link_rate $link_rate $host_delay $mean_link_delay 
    $leaf schedule $sim_end snode dnode flowsize interval
} else {
    set ft [new Fat-tree]
    $ft setup $ns $k $link_rate $mean_link_delay $host_delay
    #$ft schedule $sim_end snode dnode flowsize interval
    set ct 1
    set src 0
    set dst 14
    set flowsiz 30
    $ft rtt $ct $src $dst $flowsiz
}

puts "Initial agent creation done\n";flush stdout
puts "NS RUN!\n"
puts "********************************************\n"

$ns run

