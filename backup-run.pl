#!/usr/bin/perl -w
$topo = 0;
$sim_end = 30; #num of flows
#@load = (0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8);
#@load = (0.1, 0.2);
@load = (0.1);
@repflow_maxnum =(0,1);
$miceflow_thresh = 100;

# for web search workload
#$workload = "cdf/CDF_web-search.tcl"
#$meanFlowSize = 1138*1460;
#$type = "web"

# for data mining workload
$workload = "cdf/CDF_data-mining.tcl";
$meanFlowSize = 5117*1460;
$type = "data";

# for Pareto distribution
#$workload = "Pareto"
#$meanFlowSize = (100*1460);
#$type = "pareto"

# topology settings
# for leaf-spine topo
$spt = 16; #server per tor
$tor_num = 9;
$spine_num = 4;
# for fat-tree topo
$port_num = 4;

# routing_method
# 0 : per-flow multipath with collision in 50% of the time
# 1 : per-flow multipath without collision
# 2 : static hash routing
# 3 : per-packet multipath
@routing_method = (3);

# link_rate Mbps
$link_rate = 10000;
$link_delay = 0.0000002;
$host_delay = 0.0000025;

$queueSize = (225);
@run = (2);

$begin = qx(date +%s);
##########################################################
#create_workload($topo,$sim_end,$link_rate,$spine_num,$tor_num,$spt,$k,$load,$run,$meanFlowSize,$workload);
##########################################
# Run Simulations
##########################################
#$script = "rtt.tcl";
$script = "repflow.tcl";

foreach (@run) {
    $r = $_;
    foreach (@load) {
        $cur_load = $_;
        create_workload($topo,$sim_end,$link_rate,$spine_num,$tor_num,$spt,$port_num,$cur_load,$r,$meanFlowSize,$workload);
    }
}
foreach (@run) {
    $r = $_;
    my ($seed1,$seed2,$seed3) = get_seed($r);
    $output_dir = "/home/wfg/Desktop/stat-$sim_end/stat$r-$type-$sim_end";

    foreach (@routing_method) {
        $rm = $_;
        $flow_trace_dir = "$output_dir/trace$r-$sim_end-$rm-$type";
        if (!(-e $flow_trace_dir)) { `mkdir -p $flow_trace_dir`; }

        $log_dir = "$output_dir/log$r-$sim_end-$rm-$type";
        if (!(-e $log_dir)) { `mkdir -p $log_dir`; }

        foreach (@load) {
            $cur_load = $_;
            foreach (@repflow_maxnum) {
                $repnum = $_;
                simulate($rm,$cur_load,$repnum);
            }
        }
    }
}

sub simulate {
    my ($rm,$cur_load,$repflow_num) = @_;

    $flowTrace = "$flow_trace_dir/flow-$sim_end-$cur_load-$repflow_num-$rm.tr";
    $log = "$log_dir/$sim_end-$cur_load-$repflow_num-$rm.log";

    $arguments = "$sim_end $link_rate $link_delay $host_delay $queueSize $cur_load $spt $tor_num $spine_num $port_num $rm $repflow_num $miceflow_thresh $flowTrace $seed1 $seed2 $seed3 $workload $meanFlowSize $topo";

    my $begin = qx(date +%s);
    print "Simulation $sim_end-$cur_load-$repflow_num-$rm started!\n";
    `ns $script $arguments > $log`;
    my $end = qx(date +%s);
    my $duration = $end-$begin;
    open(my $fd, '>>', $log) or die "file open failed";
    print $fd "Simulation $sim_end-$cur_load-$repflow_num-$rm finished in $duration seconds\n";
    print "Simulation $sim_end-$cur_load-$repflow_num-$rm finished in $duration seconds\n";
    close $fd;
}

sub get_seed {
    my $k = @_;
    $seed1 = 41*$k+193*($k*$k);
    $seed2 = 113*$k+83*($k*$k);
    $seed3 = 271*$k+71*($k*$k);

    return ($seed1,$seed2,$seed3);
}

sub create_workload {
    my ($topo,$sim_end,$link_rate,$spine_num,$tor_num,$spt,$k,$load,$run,$meanFlowSize,$cdf_file) = @_;
    my ($seed1,$seed2,$seed3) = get_seed($run);
    my $argument = "$topo $sim_end $link_rate $spine_num $tor_num $spt $k $load $seed1 $seed2 $seed3 $meanFlowSize $cdf_file";
    `ns create_workload.tcl $argument > workload_creation.log`;
}

$duration = qx(date +%s)-$begin;
print "All Simulations Done in $duration seconds\n";
