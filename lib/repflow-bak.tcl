source tcp-pair.tcl
source workload.tcl

set ns [new Simulator]
set sim_start [clock seconds]

if {$argc != 19} {
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
set topology_spt [lindex $argv 6]
set topology_tors [lindex $argv 7]
set topology_spines [lindex $argv 8]
set topology_x [lindex $argv 9]

#### Routing method
set routing_method [lindex $argv 10]

#### Repflow settings
set repflow_maxnum [lindex $argv 11]
set miceflow_thresh [lindex $argv 12]
set trace_file [lindex $argv 13]
set seed1 [lindex $argv 14]
set seed2 [lindex $argv 15]
set seed3 [lindex $argv 16]

set cdf_file [lindex $argv 17]
set meanFlowSize [lindex $argv 18]

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
puts "CDF type : $cdf_file"
puts "meanFlowSize : $meanFlowSize"

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
Queue/DropTail set queue_in_bytes_ false
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
                puts "Routing method : per-flow multipath with collision in [expr 100.0 * $collision_chances/$total_chances]% of time\n"
        }
        2 {
                Classifier/MultiPath set perflow_ 1
                Classifier/MultiPath set total_chances_ 4
                Classifier/MultiPath set collision_chances_ 0
                puts "Routing method : per-flow multipath without collision\n"
        }
        3 {
                Classifier/MultiPath set perflow_ 0
                puts "Routing method : per-packet multipath\n"
        }
        4 {
    
        }
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
set UCap [expr $link_rate * $topology_spt / $topology_spines / $topology_x] ; #uplink rate

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

    #$ns queue-limit $s($i) $n($j) 10000

    $ns duplex-link-op $s($i) $tor($j) queuePos -0.5    
}

for {set i 0} {$i < $topology_tors} {incr i} {
    for {set j 0} {$j < $topology_spines} {incr j} {
	$ns duplex-link $tor($i) $core($j) [set UCap]Mb $mean_link_delay DropTail
	$ns duplex-link-op $tor($i) $core($j) queuePos 0.25
    }
}
############# Some Other Parameters #################################
#
#
set load_dir "rndnum"
if {![file exists $load_dir]} {
        file mkdir $load_dir
}
set cs_pair_file  "$load_dir/cs_pair-$sim_end-$S-$seed1.txt"
set inter_size_file "$load_dir/inter_size-$sim_end-$load-$link_rate-$seed2-$seed3.txt"

set flow_log [open $trace_file w]

##############################  Workload Generation    #########################

set avg_inter_arrival [expr ($meanFlowSize*8.0)/($link_rate*1000000*$S*$load)]
puts "Arrival at the most load : Poisson with inter-arrival [expr $avg_inter_arrival*$load * 1000000] us\n"
puts "Arrival : Poisson with inter-arrival [expr $avg_inter_arrival * 1000000] us\n"



#set maxnum_of_flows [expr $sim_end* ($repflow_maxnum+1)]

# initialization
for {set i 0} {$i < $sim_end} {incr i} {
        set snode($i) 0
        set dnode($i) 0
        set interval($i) 0
        set flowsize($i) 0
}

set refresh_needed 1
if {$refresh_needed == 1 || ![file exists $cs_pair_file]} {
        create_cs_pair $S $sim_end $cs_pair_file $seed1
}
if {$refresh_needed == 1 || ![file exists $inter_size_file]} {
        create_interval_size $sim_end $avg_inter_arrival $inter_size_file $cdf_file $seed2 $seed3
}

load_cs_pair $cs_pair_file snode dnode
load_interval_size $inter_size_file interval flowsize

# debug
#for {set i 0} {$i < $sim_end} {incr i} {
        #puts "$snode($i) $dnode($i)";flush stdout
#}
#for {set i 0} {$i < $sim_end} {incr i} {
        #puts "$interval($i) $flowsize($i)";flush stdout
#}
puts "Workload generation done\n"; flush stdout


################### tcp connection setup ###########################################
puts "Setting up connections ...\n"; flush stdout

# current time in simulation
set ct 2
set scheduled_num 0
set num_of_live_flows 0
set num_of_dead_flows 0
set repflow_count 0
set flow_num 0
for {set i 0} {$i < $sim_end } {incr i} {
        set repflow_num $repflow_maxnum
        set ct [expr $ct + $interval($i)]

        set flows($flow_num) [new TCP_pair]
        $flows($flow_num) setup s $snode($i) $dnode($i) $ct $flowsize($i) $flow_num 0 $flow_log
        incr flow_num

        while { $flowsize($i) <= $miceflow_thresh && $repflow_num>0 } {
                set flows($flow_num) [new TCP_pair]
                $flows($flow_num) setup s $snode($i) $dnode($i) $ct $flowsize($i) $flow_num 1 $flow_log
                set repflow_num [expr $repflow_num - 1]
                incr flow_num
                incr repflow_count
        }
        while {$scheduled_num < $flow_num} {
                $flows($scheduled_num) start
                incr scheduled_num
        }
}

puts "Initial agent creation done\n";flush stdout
puts "NS RUN!\n"
puts "********************************************\n"

$ns run
