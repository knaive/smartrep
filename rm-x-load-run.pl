#!/usr/bin/perl -w

$topo = 0;
$run = 5; # times to run the simulations
$sim_end = 3000; #num of flows
@load = (0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8);
#@load = (0.1, 0.2, 0.3);
#@load = (0.1,0.8);
@repflow_maxnum =(1);
$DCTCP = 0;
$smartRep = 0;
$workload_type = 1;

# for DCTCP workload
$workload = "cdf/CDF_web-search.tcl";
$meanFlowSize = 1138*1460;
$type = "web";
if ($workload_type == 1) {
# for VL2 workload
    $workload = "cdf/CDF_data-mining.tcl";
    $meanFlowSize = 5117*1460;
    $type = "data";
} elsif($workload_type == 2){
# for Pareto distribution
    $workload = "Pareto";
    $meanFlowSize = (100*1460);
    $type = "pareto";
}

# topology settings
# for leaf-spine
$spt = 16; #server per tor
$tor_num = 9;
$spine_num = 4;
# for fat-tree
$port_num = 8;

# routing_method
# 0 : per-flow multipath with collision in 25% of the time
# 1 : per-flow multipath without collision
# 2 : static hash routing
# 3 : per-packet multipath
#@routing_method = (0,1,2,3);
#@routing_method = (0,1,2);
#@routing_method = (1,2);
@routing_method = (1);

# link_rate Mbps
$link_rate = 10000;
$link_delay = 0.0000002;
$host_delay = 0.0000025;

$queueSize = 225;
$miceflow_thresh = 100;

$clear = 0;
if ($clear == 1) {
    `rm -f plot_data rude_data`;
}

##########################################
# Run Simulations
##########################################

# create workload before the first process spawn
for(my $r = 1; $r<=$run; $r++) {
    foreach (@load) {
        my $cur_load = $_;
        create_workload($topo,$sim_end,$link_rate,$spine_num,$tor_num,$spt,$port_num,$cur_load,$r,$meanFlowSize,$workload);
    }
}

my $begin = qx(date +%s);
my $pid = 0;
my @pids = ();
for(my $r = 1; $r<=$run; $r++) {
    my $start = qx(date +%s);
    print "Run $r start\n";

    foreach (@load) {
        my $cur_load = $_;

        foreach (@routing_method) {
            my $cur_rt = $_;
            $pid = fork();
            if (!$pid) {
                simulate($cur_load,$cur_rt,$r);
                exit 0;
            } else {push @pids,$pid;}
        }
    }
    foreach (@pids) {
        waitpid($_,0);
    }

    my $dur = qx(date +%s)-$start;
    print "Run $r finished in $dur seconds\n"
}


my $dur = qx(date +%s)-$begin;
print "All Simulations Done in $dur Seconds\n";

sub simulate{
    my ($cur_load,$rm,$run) = @_;
    my ($seed1,$seed2,$seed3) = get_seed($run);

    $output_dir = "/home/wfg/Desktop/stat-$sim_end-$type-1-1/stat$run-$type-$sim_end";

    my $flow_trace_dir = "$output_dir/trace$run-$sim_end-$rm-$type";
    if (!(-e $flow_trace_dir)) {`mkdir -p $flow_trace_dir`; }

    my $log_dir = "$output_dir/log$run-$sim_end-$rm-$type";
    if (!(-e $log_dir)) {`mkdir -p $log_dir`; }

    foreach (@repflow_maxnum) {
        my $repflow_num = $_;

        my $trace_file = "$flow_trace_dir/flow-$sim_end-$cur_load-$repflow_num-$rm.tr";
        my $log = "$log_dir/$sim_end-$cur_load-$repflow_num-$rm.log";

        my $arguments = "$sim_end $link_rate $link_delay $host_delay $queueSize $cur_load $spt $tor_num $spine_num $port_num $rm $repflow_num $miceflow_thresh $trace_file $seed1 $seed2 $seed3 $workload $meanFlowSize $topo $DCTCP $smartRep";

        my $begin = qx(date +%s);
        print "Simulation $sim_end-$cur_load-$repflow_num-$rm started!\n";
        `ns build.tcl $arguments > $log`;

        while ($? != 0) {
            if ($? == -1) {
                print "failed to execute: $!\n";
            } elsif ($? & 127) {
                printf "child died with signal %d, %s coredump\n",($? & 127), ($? & 128) ? 'with' : 'without';
            } else {printf "child exited with value %d\n", $?>>8;}

            print "execute again!\n";
            `ns build.tcl $arguments > $log`;
        }

        my $end = qx(date +%s);
        my $duration = $end-$begin;
        open(my $fd, '>>', $log) or die "file open failed";
        print $fd "Simulation $sim_end-$cur_load-$repflow_num-$rm finished in $duration seconds\n";
        print "Simulation $sim_end-$cur_load-$repflow_num-$rm finished in $duration seconds\n";
        close $fd;
    }
}

sub get_seed {
    my ($k) = @_;
    #print "k$k\n";
    $seed1 = 41*$k+193*($k*$k);
    $seed2 = 113*$k+83*($k*$k);
    $seed3 = 271*$k+71*($k*$k);

    #print "$seed1,$seed2,$seed3\n";
    return ($seed1,$seed2,$seed3);
}

sub create_workload {
    my ($topo,$sim_end,$link_rate,$spine_num,$tor_num,$spt,$k,$load,$run,$meanFlowSize,$cdf_file) = @_;
    my ($seed1,$seed2,$seed3) = get_seed($run);
    #print "Run$run\n";
    #print "$seed1,$seed2,$seed3\n";
    my $argument = "$topo $sim_end $link_rate $spine_num $tor_num $spt $k $load $seed1 $seed2 $seed3 $meanFlowSize $cdf_file";
    `ns create_workload.tcl $argument > workload_creation.log`;
}
