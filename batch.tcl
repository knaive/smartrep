set topdir "/home/wfg/repflow-traces"
set dirs [glob $topdir/stat*]
set plot_lst {{0 1} {1 1} {0 0} {1 0}}

foreach fullpath $dirs {
    puts "$fullpath"
    set dir_list [split $fullpath '/']
    set dir [lindex $dir_list 4]
    puts "$dir"
    set lst [split $dir "-"]
    puts "$lst"
    set sim_end [lindex $lst 1]
    set topo [lindex $lst 2]
    set load_type [lindex $lst 3]
    set collisionP [lindex $lst 4]
    set run_times 10

    puts "$sim_end $topo $load_type $collisionP "

    exec ns batch-proc.tcl $sim_end $topo $load_type $collisionP $run_times $topdir
}
