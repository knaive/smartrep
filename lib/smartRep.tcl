# generate a flow size file "outfile" according cdf file "filenm"
proc createFlowSize {filenm num round outfile} {
    set fd [open $outfile w]

    for {set i 0} {$i < $round} {incr i} {
        set rng [new RNG]
        $rng seed [expr {10+round(rand()*20000)}]
        set flowsize [new RandomVariable/Empirical]
        $flowsize use-rng $rng
        $flowsize set interpolation_ 2
        $flowsize loadCDF $filenm
        
        for {set j 0} {$j < $num} {incr j} {
            puts $fd "[expr round ([$flowsize value])]"
        }
    }

    close $fd
}

# calcuate "NUM"(a array containing traffic of specific flowsize) and "accu"(total traffic) in the constrant from file "filenm"
proc getPara {filenm SL NUM} {
    upvar $NUM num
    set fd [open $filenm r]
    set accu 0

    for {set i 1} {$i <= $SL} {incr i} {
        set num($i) 0
    }

    for {set i 1} {[gets $fd line]>=0} {incr i} {
        set lst [split $line " "]
        set k [lindex $line 0]
        if {$k <= $SL} {
            set num($k) [expr $num($k)+1]
        }
        set accu [expr $accu+$k]
    }
    return $accu
}

# find the next "repNum($k)" that can be incremented 
proc getNext {Obj Eta Usable SL} {
    upvar $Obj obj
    upvar $Eta eta
    upvar $Usable T

    set maxObj 0
    set k 0
    set minEta 10000000
    for {set i 1} {$i <= $SL} {incr i} {
        if {$T($i)!=0 && ($obj($i)>$maxObj || $obj($i)==$maxObj && $eta($i)<$minEta)} {
                set maxObj $obj($i)
                set k $i
                set minEta $eta($i)
        }
    }
    return $k
}

proc createRepNumFile {filenm RepNum prob beta percent outfile} {
    upvar $RepNum repNum

    set SL 100
    # pi($i) is the number of flows carrying i KB
    set threshold [getPara $filenm $SL pi]

    set threshold [expr $percent*$threshold]
    for {set i 1} {$i <= $SL} {incr i} {
        # sum of obj array is the objective function value
        set obj($i) [expr $pi($i)*$prob]
        set eta($i) [expr $pi($i)*$i]
        set repNum($i) 0
        if {$pi($i) == 0} {
            set T($i) 0
        } else {
            set T($i) 1
        }
    }
    puts "$threshold"

    set sum 0
    set flag 1
    while {$flag != 0} {
        set k [getNext obj eta T $SL]

        while {$k!=0 && $sum+$eta($k)>$threshold } {
            set T($k) 0
            set k [getNext obj eta T $SL]
        }
        if {$k == 0} {
            break
        }

        if {$repNum($k) < $beta} {
            set repNum($k) [expr $repNum($k)+1]
            set sum [expr $sum+$eta($k)]
            set obj($k) [expr $obj($k)*$prob]
        } else {
            set T($k) 0
        }

        set flag 0
        for {set i 1} {$i <= $SL} {incr i} {
            set flag [expr $flag+$T($i)]
        }
    }

    set fd [open $outfile w]
    for {set i 1} {$i <= $SL} {incr i} {
        puts $fd "$repNum($i)"
    }
    close $fd
}

proc load_repNum {filenm RepNum} {
    upvar $RepNum repNum

    set fd [open $filenm r]
    for {set i 1} {[gets $fd line]>=0} {incr i} {
        set repNum($i) $line
    }
    close $fd
}
