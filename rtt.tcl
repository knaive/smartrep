source lib/tcp-pair.tcl
source lib/workload.tcl


set ns [new Simulator]
set all_traces [open flow.tr w]
# trace-all command must appear immediately after creating scheduler
$ns trace-all $all_traces

set start_time [clock seconds]

set sim_end 50
set link_rate 10000
set mean_link_delay 0.0000002
set host_delay 0.0000025
set queueSize 225
set load 1.0

#### topology
set topology_spt 16
set topology_tors 9
set topology_spines 2
set topology_x 1

#### Routing method
set routing_method 2

#### Repflow settings
set eleph_num 0
set miceflow_thresh 100
set seed1 777
set seed2 10234
set seed3 137
set avg_inter_arrival 20000

set trace_dir "trace"
if {![file exists $trace_dir]} {
    file mkdir $trace_dir
}
set flowTrace "$trace_dir/flow-$sim_end-$eleph_num.tr"

#### Packet size is in bytes.
set pktSize 1460

puts "Simulation input:" 
puts "topology: spines server per rack = $topology_spt, x = $topology_x"
puts "sim_end $sim_end"
puts "link_rate $link_rate Mbps"
puts "link_delay $mean_link_delay sec"
puts "RTT  [expr $mean_link_delay * 2.0 * 6] sec"
puts "host_delay $host_delay sec"
puts "queue size $queueSize pkts"
puts "load $load"
puts "pktSize(payload) $pktSize Bytes"
puts "pktSize(include header) [expr $pktSize + 40] Bytes"

################# Transport Options ####################

Agent/TCP set packetSize_ $pktSize
Agent/TCP/FullTcp set segsize_ $pktSize
Agent/TCP/FullTcp set spa_thresh_ 0
Agent/TCP set windowOption_ 0
Agent/TCP set tcpTick_ 0.000001
Agent/TCP set maxrto_ 2

Agent/TCP/FullTcp set nodelay_ true; # disable Nagle
Agent/TCP/FullTcp set interval_ 0.000006
Agent/TCP set window_ 1000000
Agent/TCP set windowInit_ 1
if {$queueSize > 12} {
   Agent/TCP set maxcwnd_ [expr $queueSize - 1];
} else {
   Agent/TCP set maxcwnd_ 12;
}
#Agent/TCP/FullTcp set prob_cap_ $prob_cap_;
set myAgent "Agent/TCP/FullTcp/Newreno";

################# Switch Options ######################

Queue set limit_ $queueSize
Queue/DropTail set queue_in_bytes_ true
Queue/DropTail set mean_pktsize_ [expr $pktSize+40]

############## Multipathing ###########################

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
                Classifier/MultiPath set perflow_ 0
                $ns rtproto DV
                puts "Routing method : per-packet multipath\n"
        }
        4 { puts "static src-dst based hash routing\n"}
        default {
                puts "Wrong routing method!"
                exit 0
        }
} 
############# Topoplgy #########################

$ns color 0 Red
$ns color 1 Orange
$ns color 2 Yellow
$ns color 3 Green
$ns color 4 Blue
$ns color 5 Violet
$ns color 6 Brown
$ns color 7 Black

set S [expr $topology_spt * $topology_tors] ; #number of servers
#set UCap [expr $link_rate * $topology_spt / $topology_spines / $topology_x] ; #uplink rate
set UCap $link_rate 

puts "UCap: $UCap" 

for {set i 0} {$i < $S} {incr i} {
    set s($i) [$ns node]
}

for {set i 0} {$i < $topology_tors} {incr i} {
    set tor($i) [$ns node]
    $tor($i) shape box
    $tor($i) color green
}

for {set i 0} {$i < $topology_spines} {incr i} {
    set core($i) [$ns node]
    $core($i) color blue
    $core($i) shape box
}

for {set i 0} {$i < $S} {incr i} {
    set j [expr $i/$topology_spt]
    $ns simplex-link $s($i) $tor($j) [set link_rate]Mb [expr $host_delay + $mean_link_delay] DropTail
    $ns simplex-link $tor($j) $s($i) [set link_rate]Mb [expr $host_delay + $mean_link_delay] DropTail
}

for {set i 0} {$i < $topology_tors} {incr i} {
    for {set j 0} {$j < $topology_spines} {incr j} {
        $ns duplex-link $tor($i) $core($j) [set UCap]Mb $mean_link_delay DropTail
    }
}

################### tcp connection setup ###########################################
puts "Setting up connections ...\n"; flush stdout
set flow_log [open $flowTrace w]

# current time in simulation
set ct 0.5
set scheduled_num 0
set num_of_live_flows 0
set num_of_dead_flows 0
set repflow_maxnum 1
set flow_num 0

set flowsize 5

set ct [expr $ct + 0.1]
set cs_pair [new CS_pair]
$cs_pair setup 1 143
$cs_pair create_flow s $ct 100000 $flow_log
incr flow_num

set ct [expr $ct + 0.001]
set cs_pair [new CS_pair]
$cs_pair setup 0 142
$cs_pair create_flow s $ct $flowsize $flow_log
incr flow_num

puts "Initial agent creation done\n";flush stdout
puts "NS RUN!\n"
puts "********************************************\n"

$ns run
