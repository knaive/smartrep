source lib/workload.tcl

if {[llength $argv]!=14} {
    puts "Wrong arguments number!"
    exit 0
}

set topo [lindex $argv 0]
set sim_end [lindex $argv 1]
set link_rate [lindex $argv 2]
set spine_num [lindex $argv 3]
set tor_num [lindex $argv 4]
set spt [lindex $argv 5]
set k [lindex $argv 6]
set load [lindex $argv 7]
set seed1 [lindex $argv 8]
set seed2 [lindex $argv 9]
set seed3 [lindex $argv 10]
set meanFlowSize [lindex $argv 11]
set cdf_file [lindex $argv 12]
set load_type [lindex $argv 13]


# 0 for fat-tree
# 1 for Leaf-spine
if {$topo} {
    set host_num [expr $tor_num*$spt]
    set max_goodput [expr $link_rate*$spine_num*$tor_num]
} else {
    set host_num [expr $k*$k*$k/4]
    set max_goodput [expr $link_rate*$host_num]
}

set load_dir "rndnum"
if {![file exists $load_dir]} { file mkdir $load_dir }
set cs_pair_file  "$load_dir/cs_pair-$sim_end-$host_num-$seed1.txt"
set inter_size_file "$load_dir/inter_size-$sim_end-$load-$link_rate-$seed2-$seed3.txt"

set avg_inter_arrival [expr ($meanFlowSize*8.0)/($max_goodput*1000000*$load)]

create_cs_pair $host_num $sim_end $cs_pair_file $seed1
create_interval_size $sim_end $avg_inter_arrival $inter_size_file $cdf_file $seed2 $seed3 $load_type

puts "Workload generation done\n"; flush stdout
