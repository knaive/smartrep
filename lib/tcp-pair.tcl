#

Class TCP_pair
TCP_pair instproc init {args} {
        $self instvar tcps tcpr
        global myAgent
        eval $self next $args

        $self set tcps [new $myAgent]  ;# Sender TCP
        $self set tcpr [new $myAgent]  ;# Receiver TCP

        $tcps set_callback $self

        $self set debug_mode 1
}

TCP_pair instproc set_debug_mode { mode } {
        $self instvar debug_mode
        $self set debug_mode $mode
}

TCP_pair instproc setup {s snode dnode start_time flowsize fid replicated is_mice} {
        global ns pktSize flow_log
        $self instvar tcps tcpr fid_ flowsize_ replicated_ snode_ dnode_ start_time_
        upvar $s server

        $ns attach-agent $server($snode) $tcps
        $ns attach-agent $server($dnode) $tcpr

        $self set fid_ $fid
        $tcps set fid_ $fid
        $tcpr set fid_ $fid
        $self set snode_ $snode
        $self set dnode_ $dnode
        # bytes
        $self set flowsize_ [expr $flowsize * $pktSize]
        $self set replicated_ $replicated
        $self set start_time_ $start_time

        $tcps set prio_ $replicated
        $tcpr set prio_ $replicated

        $tcpr listen
        $ns connect $tcps $tcpr
}

TCP_pair instproc setfid { fid } {
        $self instvar tcps tcpr
        $self instvar fid_
        $self set fid_ $fid
        $tcps set fid_ $fid;
        $tcpr set fid_ $fid;
}

TCP_pair instproc start {} {
        global ns num_of_live_flows 

        $self instvar tcps tcpr 
        $self instvar start_time_ flowsize_

        $self instvar debug_mode

        $tcpr set flow_remaining_ [expr $flowsize_]
        $tcps set signal_on_empty_ TRUE

        $ns at $start_time_ "incr num_of_live_flows"
        $ns at $start_time_ "$tcps advance-bytes $flowsize_"
}


TCP_pair instproc fin_notify {} {
        global flow_total_num num_of_dead_flows num_of_live_flows ns pktSize flow_log
        $self instvar snode_ dnode_
        $self instvar fid_ flowsize_ replicated_
        $self instvar fct start_time_ tcps

        $self set fct [expr [$ns now] - $start_time_]

        #puts $flow_log "ct($ct), src($snode_), dst($dnode_), fid($fid_), fct($fct), flowsize($flowsize_), replicated($replicated_)"
        set outStr "[expr $start_time_*1000000],$snode_,$dnode_,$fid_,[expr $fct*1000000],[expr $flowsize_ / $pktSize],$replicated_"
        puts $flow_log $outStr

        incr num_of_dead_flows
        set num_of_live_flows [expr $num_of_live_flows - 1]
        #puts "RTT : [$tcps set rtt_], Smoothed RTT : [$tcps set srtt_]\n"; flush stdout
        puts "flow($outStr) finished, $num_of_dead_flows/$num_of_live_flows/$flow_total_num\n"; flush stdout
        if {$num_of_dead_flows == $flow_total_num} {
                finish
        }
}

Agent/TCP/FullTcp instproc set_callback {tcp_pair} {
        $self instvar ctrl
        $self set ctrl $tcp_pair
}

Agent/TCP/FullTcp instproc done_data {} {
        $self instvar ctrl
        #
        #puts "[$ns now] $self fin-ack received";
        #
        if { [info exists ctrl] } {
                $ctrl fin_notify
        }
}


Class CS_pair

CS_pair instproc init {args} {
    $self instvar flow_num 
    #$self instvar origin_flow_num
    $self set flow_num 0
    #$self set origin_flow_num 0
}
CS_pair instproc setup {client server enableSmartRep} {
    $self instvar src dst smartRep
    $self set src $client
    $self set dst $server
    $self set smartRep $enableSmartRep
}

CS_pair instproc create_flow {s ct flowsize } {
    global miceflow_thresh repflow_maxnum flow_total_num origin_flow_num repNum

    $self instvar flow_num src dst
    $self instvar flows
    $self instvar smartRep
    upvar $s server

    set is_mice 0
    if { $flowsize <= $miceflow_thresh} {
        set is_mice 1
    }

    $self set flows($flow_num) [new TCP_pair]
    $flows($flow_num) setup server $src $dst $ct $flowsize $origin_flow_num 0 $is_mice
    $flows($flow_num) start

    set var 1
    incr origin_flow_num
    incr flow_num
    incr flow_total_num

    if {$is_mice && $smartRep == 1} {
        set count $repNum($flowsize)
        set k 4
        # if src and dst in the same subnet
        if {[expr $src/$k]==[expr $dst/$k]} {
            set count 0
        }
        # debug
        puts "$src to $dst $flowsize $count"
    } else {
        set count $repflow_maxnum
    }

    while { $is_mice && $count>0 } {
        $self set flows($flow_num) [new TCP_pair]
        $flows($flow_num) setup server $src $dst $ct $flowsize [expr $origin_flow_num + $var -1] 1 $is_mice
        $flows($flow_num) start
        incr var
        incr flow_num
        incr flow_total_num
        set count [expr $count-1]
    }
}

proc finish {} {
        global ns flow_log start_time enable_flow_traces
        $ns flush-trace
        close $flow_log
        if {$enable_flow_traces} {
            global all_traces
            close $all_traces
        }

        puts "Simulation finished in [expr [clock seconds]-$start_time] seconds"
        exit 0
}
