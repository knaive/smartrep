############# Workload Generation #########################
#
#
# generate random client/server pairs and put them into a file
proc create_cs_pair {S flows_maxnum cs_pair_file rands} {
        puts "create_cs_pair\n"; flush stdout
        set rng [new RNG]
        $rng seed $rands

        set fd [open $cs_pair_file w]

        set host_num [new RandomVariable/Uniform]
        $host_num use-rng $rng
        $host_num set min_ 0
        $host_num set max_ [expr $S - 1]

        for {set i 0} {$i < $flows_maxnum} {incr i} {
               set client [expr round ([$host_num value])] 
               set server [expr round ([$host_num value])]
               while {$server == $client} {
                       set server [expr round ([$host_num value])]
               }
               puts $fd "$client $server"
        }
        close $fd
}

# generate interval and flow size , then write them into a file
proc create_interval_size {flows_maxnum avg_inter_arrival interval_size_file cdffile s1 s2} {
        puts "create_interval_size\n"; flush stdout
        global load link_rate meanFlowSize 

        set rng1 [new RNG]
        $rng1 seed $s1
        set flow_intval [new RandomVariable/Exponential]
        $flow_intval use-rng $rng1
        $flow_intval set avg_ $avg_inter_arrival

        set rng2 [new RNG]
        $rng2 seed $s2
        set flow_size [new RandomVariable/Empirical]
        $flow_size use-rng $rng2
        $flow_size set interpolation_ 2
        $flow_size loadCDF $cdffile

        set fd [open $interval_size_file w]
        for {set i 0} {$i < $flows_maxnum} {incr i} {
                puts $fd "[$flow_intval value] [expr round ([$flow_size value])]"
        }
        close $fd
}
proc create_interval_size1 {flows_maxnum interval_size_file cdffile s1 s2} {
        puts "create_interval_size\n"; flush stdout
        global load link_rate meanFlowSize lambda

        #puts "FlowSize: Pareto with mean = $meanFlowSize, shape = $paretoShape"
        set rng2 [new RNG]
        $rng2 seed $s2
        set flow_size [new RandomVariable/Empirical]
        $flow_size use-rng $rng2
        $flow_size set interpolation_ 2
        $flow_size loadCDF $cdffile
        #compute meanFlowSize
        set meanFlowSize 0
        for {set i 0} {$i < $flows_maxnum} {incr i} {
                set flowsiz($i) [expr round ([$flow_size value])]
                set meanFlowSize [expr $meanFlowSize + $flowsiz($i)]
        }
        set meanFlowSize [expr $meanFlowSize/$flows_maxnum]
        

        set lambda [expr ($link_rate*$load*1000000000)/($meanFlowSize*8.0/1460*1500)]
        set rng1 [new RNG]
        $rng1 seed $s1
        set flow_intval [new RandomVariable/Exponential]
        $flow_intval use-rng $rng1
        $flow_intval set avg_ [expr 1.0/$lambda]


        set fd [open $interval_size_file w]
        for {set i 0} {$i < $flows_maxnum} {incr i} {
                puts $fd "[$flow_intval value] $flowsiz($i)"
        }
        close $fd
}

# load random cline/server pair
proc load_cs_pair {cs_pair_file snode dnode} {
        upvar $snode src
        upvar $dnode dst
        set fd [open $cs_pair_file r]
        for {set i 0} {[gets $fd line] >= 0} {incr i} {
                set cs_pair [split $line " "]  
                set src($i) [lindex $cs_pair 0]
                set dst($i) [lindex $cs_pair 1]
        }
        close $fd
}

# load intervals and flow size
proc load_interval_size {inter_size_file interval flowsize} {
        upvar $interval inter
        upvar $flowsize flowsiz
        set fd [open $inter_size_file r]
        for {set i 0} {[gets $fd line] >= 0} {incr i} {
                set pair [split $line " "]
                set inter($i) [lindex $pair 0]
                set flowsiz($i) [lindex $pair 1]
        }
        close $fd
        return $i
}
