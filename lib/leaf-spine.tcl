Class Leaf-spine

Leaf-spine instproc init {} {

}

Leaf-spine instproc setup {ns_ torNum spt spineNum DCap UCap hostDelay linkDelay} {
    $self instvar ns
    $self instvar s tor core
    $self instvar tor_num host_per_tor spine_num host_num
    $self instvar downlink_rate uplink_rate
    $self instvar host_delay link_delay 

    $self set ns $ns_

    $self set tor_num $torNum
    $self set host_per_tor $spt
    $self set spine_num $spineNum
    $self set host_num [expr $tor_num*$host_per_tor] 

    $self set downlink_rate $DCap ;# donwlink rate
    $self set uplink_rate $UCap ;#uplink rate

    $self set host_delay $hostDelay
    $self set link_delay $linkDelay


    for {set i 0} {$i < $host_num} {incr i} {
        $self set s($i) [$ns node]
    }

    for {set i 0} {$i < $tor_num} {incr i} {
        $self set tor($i) [$ns node]
        $tor($i) shape box
        $tor($i) color green
    }

    for {set i 0} {$i < $spine_num} {incr i} {
        $self set core($i) [$ns node]
        $core($i) color blue
        $core($i) shape box
    }

    for {set i 0} {$i < $host_num} {incr i} {
        set j [expr $i/$host_per_tor]
        $ns simplex-link $s($i) $tor($j) [set downlink_rate]Mb [expr $host_delay + $link_delay] DropTail
        $ns simplex-link $tor($j) $s($i) [set downlink_rate]Mb [expr $host_delay + $link_delay] DropTail

        $ns duplex-link-op $s($i) $tor($j) queuePos -0.5    
    }

    for {set i 0} {$i < $tor_num} {incr i} {
        for {set j 0} {$j < $spine_num} {incr j} {
            $ns duplex-link $tor($i) $core($j) [set uplink_rate]Mb $link_delay DropTail
            $ns duplex-link-op $tor($i) $core($j) queuePos 0.25
        }
    }
}

Leaf-spine instproc schedule {sim_end snode dnode flowsize interarrival} {
    upvar $snode sn
    upvar $dnode dn
    upvar $flowsize flowsiz
    upvar $interarrival interval

    $self instvar s ct

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

