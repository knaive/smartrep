source lib/data-process.tcl


# compute the average fct of several runs of simulation
proc avg {src} {
    exec sort -t , -g -k 1 $src -o $src

    set fd [open $src r]

    gets $fd line
    set lst [split $line " "]
    set load [lindex $lst 0]
    set fct [lindex $lst 1]
    set num 1

    while {[gets $fd next_line]>0} {
        set lst [split $next_line " "]
        if {$load == [lindex $lst 0]} {
            set fct [expr $fct+[lindex $lst 1]]
            incr num
        } else {
            exec echo "$load [expr $fct/$num]" >> tmp 

            set load [lindex $lst 0]
            set fct [lindex $lst 1]
            set num 1
        }
    }
    exec echo "$load [expr $fct/$num]" >> tmp
    exec cat tmp > $src
    exec rm -f tmp
    close $fd
}

# how to call proc.tcl:
# ns proc.tcl stat_topdir list1 list2 list3 ...
# list = "repnum routing_method"
set stat_topdir [lindex $argv 0]

set lst [split $stat_topdir "-"]
set sim_end [lindex $lst 1]
set load_type [lindex $lst 2]
set rm [lindex $lst 3]

set len [llength $lst]
set out_topdir "plot-$sim_end-$load_type-$rm"
for {set i 4} {$i < $len} {incr i} {
    set out_topdir "$out_topdir-[lindex $lst $i]"
}

for {set i 1} {$i < $argc} {incr i} {
    lappend plot_lst [lindex $argv $i]
}

set run_times 5
set percent 1
set link_rate 10000

for {set i 1} {$i <= $run_times} {incr i} {
    set stat_dir "$stat_topdir/stat$i-$load_type-$sim_end" 
    set plot_dir "$out_topdir/plot_data$i"
    set out_dir "$out_topdir/rude_data$i"

    set dirs [glob $stat_dir/trace*]

    foreach dir $dirs {
        data-process $dir $plot_dir $out_dir $percent $link_rate
    }
    
    set files [glob $plot_dir/*.dat]
    foreach f $files {
        set dat_file [exec basename $f]
        exec cat $f >> $out_topdir/$dat_file
    }
}

set files [glob $out_topdir/*.dat]
foreach f $files {
    exec cp $f $f.bak
    avg $f
}

plot $out_topdir $sim_end $plot_lst
set saved_dir [pwd]
#cd $out_topdir
#exec gnuplot plot.plt
#cd $saved_dir


# overhead calculation
#set overhead_dir "$out_topdir/rude_data1"
#set file_name "flow-$sim_end-0.1-$repflow_maxnum-0"
#set overhead [overhead_cal $f]
#exec cat "$f: $overhead" >> overhead.dat
