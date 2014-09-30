source lib/data-process.tcl

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

if {[llength $argv]!=5} {
    puts "Wrong Argument Number!"
    exit 0
}
set sim_end [lindex $argv 0]
set topo [lindex $argv 1]
set load_type [lindex $argv 2]
set collisionP [lindex $argv 3]
set run_times [lindex $argv 4]
set topdir [lindex $argv 5]
set plot_lst [lindex $argv 6]

set stat_topdir "$topdir/stat-$sim_end-$topo-$load_type-$collisionP"
set out_topdir "$topdir/plot-$sim_end-$topo-$load_type-$collisionP"

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
cd $out_topdir
exec gnuplot plot.plt
cd $saved_dir
