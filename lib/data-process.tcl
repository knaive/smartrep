# data processing
#
#
proc reduce { src dst } {
        set rd [open $src r]
        set wd [open $dst w]

        if {[gets $rd line] <=0} {
                return 
        }

        while {1} {
                set lst1 [split $line ","]
                set minfct [lindex $lst1 4]

                if {[gets $rd nextline] <= 0} {
                        puts $wd $line
                        break
                }
                set lst2 [split $nextline ","]

                while {[lindex $lst2 6]==1 && [lindex $lst2 1]==[lindex $lst1 1] && [lindex $lst2 2]==[lindex $lst1 2]} {
                        if {$minfct > [lindex $lst2 4]} {
                                set minfct [lindex $lst2 4]
                                set line $nextline
                        }
                        if {[gets $rd nextline]<=0} {
                                break
                        }
                        set lst2 [split $nextline ","]
                }
                puts $wd $line
                set line $nextline
        }

        close $rd
        close $wd
}

proc compute_normfct {fct pkts link_rate rtt} {
    
    #set perfect_fct [expr ($pkts*1540*8)/$link_rate+2*$rtt] ;# for leaf-spine
    set perfect_fct [expr ($pkts*1540*8)/$link_rate+2.5*$rtt] ;# for fat-tree

    return [expr $fct/$perfect_fct]
}

proc avg_normfct {filenm miceflow_thresh link_rate {percent 1}} {
        if {$percent > 1 || $percent <= 0} {
                puts "wrong percent in function normfct"
        }
        
        set fd [open $filenm r]

        # ignore the first line_num lines
        set line_num [exec wc -l $filenm]
        set line_num [split $line_num " "]
        set line_num [lindex $line_num 0]
        set line_num [expr $line_num * (1-$percent)]
        while {[gets $fd line]>0 && $line_num >0} {set line_num [expr $line_num-1]}

        # compute average fct for mice flows and elephant flows
        set mice_num 0
        set mice_avg 0
        set eleph_num 0
        set eleph_avg 0

        set micefct_file "$filenm.micefct"
        set elephfct_file "$filenm.elephfct"
        set wd [open $micefct_file  w]
        set wd1 [open $elephfct_file w]

        set rtt 11.6
        while {[gets $fd line] > 0} {
                set lst [split $line ","]
                set fct [lindex $lst 4]
                set pkts [lindex $lst 5]
                set normfct [compute_normfct $fct $pkts $link_rate $rtt]

                if {$normfct<1} {
                    puts "$normfct,$pkts,$fct"
                }

                if {[lindex $lst 5] <= $miceflow_thresh } {
                        set mice_avg [expr $mice_avg + $normfct]
                        incr mice_num
                        puts $wd $normfct
                } else {
                        set eleph_avg [expr $eleph_avg + $normfct]
                        incr eleph_num
                        puts $wd1 $normfct
                }
        }

        if {$mice_num == 0} {
                puts "Zero mice flow!"
        } else {set mice_avg [expr $mice_avg / $mice_num]}
        
        if {$eleph_num == 0} {
                puts "Zero elephant flow!"
        } else {set eleph_avg [expr $eleph_avg / $eleph_num]}

        close $fd
        close $wd
        close $wd1

        # compute mice flow 99% FCT
        exec sort -g $micefct_file -o $micefct_file
        set nth [expr round ([expr 0.99 * $mice_num])]
        set mice_99 [exec head -n $nth $micefct_file | tail -n 1]

        return [list $mice_avg $mice_99 $eleph_avg]
}

proc generate_plot_data {plot_dir filenm sim_end load repflow_num routing_method miceflow_thresh link_rate {percent 1}} {
        set lst [avg_normfct $filenm $miceflow_thresh $link_rate $percent]
        set miceavg [lindex $lst 0]
        set mice99 [lindex $lst 1]
        set elephavg [lindex $lst 2]

        set miceavg_fn "$plot_dir/mice_avgfct-$sim_end-$repflow_num-$routing_method.dat" 
        set mice99_fn "$plot_dir/mice_99fct-$sim_end-$repflow_num-$routing_method.dat" 
        set elephavg_fn "$plot_dir/eleph_avgfct-$sim_end-$repflow_num-$routing_method.dat" 

        set fd1 [open $miceavg_fn a]
        set fd2 [open $mice99_fn a]
        set fd3 [open $elephavg_fn a]

        #puts "miceavg:$miceavg, mice99:$mice99, elephavg:$elephavg\n"
        puts $fd1 "$load $miceavg"
        puts $fd2 "$load $mice99"
        puts $fd3 "$load $elephavg"

        close $fd1
        close $fd2
        close $fd3
}

proc data-process {trace_dir plot_dir out_dir percent link_rate} {
    if {![file exists $out_dir]} { file mkdir $out_dir }
    if {![file exists $plot_dir]} { file mkdir $plot_dir }

    set files [glob $trace_dir/*]
    foreach f $files {
        set bak [exec basename $f .tr]
        set lst [split $bak "-"]
        set sim_end [lindex $lst 1]
        set load [lindex $lst 2]
        set repflow_num [lindex $lst 3]
        set routing_method [lindex $lst 4]

        set bak "$out_dir/$bak"
        set filenm "$bak.dat"
        exec cp $f $bak
        exec sort -t , -k 1 -k 7 -g $bak -o $bak 

        if {$repflow_num} {
            reduce $bak $filenm
        } else {exec cat $bak > $filenm}

        generate_plot_data $plot_dir $filenm $sim_end $load $repflow_num $routing_method 100 $link_rate $percent
    }

    set files [glob $plot_dir/*]
    foreach f $files {
        exec sort -n -k 1 $f -o $f
    }
}

proc plot {dir sim_end lst} {
        set str(0) "plot"
        set str(1) "plot"
        set str(2) "plot"
        set siz [llength $lst]
        for {set i 0} {$i < $siz} {incr i} {
                set sublist [lindex $lst $i]
                set repnum($i) [lindex $sublist 0]
                set rout($i) [lindex $sublist 1]
        }
        
        for {set i 0} {$i < $siz} {incr i} {
                set str(0) "$str(0) 'mice_avgfct-$sim_end-$repnum($i)-$rout($i).dat' ls [expr $i+1] t '$repnum($i)-$rout($i)'"
                set str(1) "$str(1) 'mice_99fct-$sim_end-$repnum($i)-$rout($i).dat' ls [expr $i+1] t '$repnum($i)-$rout($i)'"
                set str(2) "$str(2) 'eleph_avgfct-$sim_end-$repnum($i)-$rout($i).dat' ls [expr $i+1] t '$repnum($i)-$rout($i)'"
                #puts "$str(0)\n$str(1)\n$str(2)"
                if {$i!=[expr $siz-1]} {
                        set str(0) "$str(0),"
                        set str(1) "$str(1),"
                        set str(2) "$str(2),"
                }
        }

        set pointsize 1.2
        set linewidth 3
        set fontsize 25

        set script "set term eps enhanced color solid font 'Times-New-Roman,$fontsize'
        set grid

        set style line 1 linecolor 0 pointtype 3 ps $pointsize lw $linewidth
        set style line 2 linecolor 1 pointtype 5 ps $pointsize lw $linewidth
        set style line 3 linecolor 2 pointtype 7 ps $pointsize lw $linewidth
        set style line 4 linecolor 3 pointtype 9 ps $pointsize lw $linewidth
        set style line 5 linecolor 4 pointtype 11 ps $pointsize lw $linewidth
        set style line 6 linecolor 5 pointtype 13 ps $pointsize lw $linewidth
        
        set style data linespoints
        set key reverse samplen 2 left top Left
        set xlabel 'Load'
        set ylabel 'Normalized FCT'
        set output 'mice-avg.eps'
        $str(0)
        set output 'mice-99.eps'
        unset key
        $str(1)
        set output 'eleph-avg.eps'
        unset key
        $str(2)"

        set fd [open $dir/plot.plt w]
        puts $fd "$script"
        close $fd
}
#

proc overhead_cal { filename } {
        set fd [open $filename r]
        set total_vol 0
        set overhead 0

        while {[gets $fd line] > 0} {
            set lst [split $line ","]
            set flowsiz [lindex $lst 5]
            if {[lindex $lst 6] == 1} {
                set overhead [expr $overhead + $flowsiz]
            }
            set total_vol [expr $total_vol + $flowsiz]
        }

        close $fd
        return [expr 1.0*$overhead/$total_vol]
}
