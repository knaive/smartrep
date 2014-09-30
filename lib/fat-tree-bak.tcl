source lib/tcp-pair.tcl

Class Fat-tree

Fat-tree instproc init {} {
}

Fat-tree instproc setup {ns_ n linkRate linkDelay hostDelay} {
    $self instvar ns
    $self instvar k link_rate link_delay host_delay
    $self instvar pod_num host_num host_per_tor tor_per_pod agg_per_pod 
    $self instvar tor_num agg_num core_num
    $self instvar s tor agg core

    $self set ns $ns_

    $self set k $n
    $self set pod_num $k
    $self set host_num [expr $k*$k*$k/4]
    $self set host_per_tor [expr $k/2]
    $self set tor_per_pod [expr $k/2]
    $self set agg_per_pod [expr $k/2]
    $self set tor_num [expr $k*$k/2]
    $self set agg_num $tor_num
    $self set core_num [expr $k*$k/4]

    $self set link_rate $linkRate
    $self set link_delay $linkDelay
    $self set host_delay $hostDelay

    #puts "k : $k"
    #puts "pod_num : $pod_num"
    #puts "host_num : $host_num"
    #puts "host_per_tor : $host_per_tor"
    #puts "tor_per_pod : $tor_per_pod"
    #puts "agg_per_pod : $agg_per_pod"
    #puts "tor_num : $tor_num"
    #puts "agg_num : $agg_num"
    #puts "core_num : $core_num"

    # create hosts
    for {set i 0} {$i < $host_num} {incr i} {
        $self set s($i) [$ns node]
    }
    # create top-of-rack switches
    for {set i 0} {$i < $tor_num} {incr i} {
        $self set tor($i) [$ns node]
        $tor($i) set edge_ 1
    }
    # create aggregation switches
    for {set i 0} {$i < $agg_num} {incr i} {
        $self set agg($i) [$ns node]
    }
    # create core switches
    for {set i 0} {$i < $core_num} {incr i} {
        $self set core($i) [$ns node]
    }


    # connect hosts to top-of-rack switches
    for {set i 0} {$i < $host_num} {incr i} {
        set tor_index [expr $i/$host_per_tor]
        $ns duplex-link $s($i) $tor($tor_index) [set link_rate]Mb [expr $link_delay+$host_delay] DropTail
        #puts "s($i) to tor($tor_index)"
    }

    # connect tor switches to aggregation switches
    for {set i 0} {$i < $agg_num} {incr i} {
        set pod_index [expr $i/$agg_per_pod]
        set first_tor [expr $pod_index * $tor_per_pod]
        set last_tor [expr $pod_index * $tor_per_pod+$tor_per_pod-1]
        for {set j $first_tor} {$j <= $last_tor} {incr j} {
            $ns duplex-link $agg($i) $tor($j) [set link_rate]Mb [set link_delay] DropTail
            #puts "agg($i) to tor($j)"
        }
    }

    # connect core switches to aggregation switches
    for {set i 0} {$i < $pod_num} {incr i} {
        set first_agg [expr $i*$agg_per_pod]
        set last_agg [expr $i*$agg_per_pod+$agg_per_pod-1]
        set core_count 0
        for {set j $first_agg} {$j <= $last_agg} {incr j} {
            for {set m 0} {$m < [expr $k/2]} {incr m} {
                $ns duplex-link $agg($j) $core($core_count) [set link_rate]Mb [set link_delay] DropTail
                #puts "agg($j) to core($core_count)"
                incr core_count
            }
        }
    }
}

Fat-tree instproc schedule {sim_end snode dnode flowsize interarrival} {
    upvar $snode sn
    upvar $dnode dn
    upvar $flowsize flowsiz
    upvar $interarrival interval
    $self instvar s host_num ct

    # current time in simulation
    $self set ct 1
    for {set i 0} {$i < $sim_end } {incr i} {
        set ct [expr $ct + $interval($i)]

        set src $sn($i)
        set dst $dn($i)

        if {![info exists cs_pairs($src,$dst)]} {
            set cs_pairs($src,$dst) [new CS_pair]
            $cs_pairs($src,$dst) setup $src $dst
        }
        $cs_pairs($src,$dst) create_flow s $ct $flowsiz($i)
    }
}
