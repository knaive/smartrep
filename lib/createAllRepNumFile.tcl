source smartRep.tcl

set repLim 4
set percent 0.02
set prob(1) 0.1
set prob(2) 0.2
set prob(3) 0.3
set prob(4) 0.4
set prob(5) 0.5
set prob(6) 0.6
set prob(7) 0.7
set prob(8) 0.8

for {set i 1} {$i <= 8} {incr i} {
    set cdffile "../cdf/CDF_web-search.tcl"
    set datfile "../cdf/web-search.dat"
    set outfile "../cdf/repnum-web-$repLim-$prob($i).dat"
    #createFlowSize $cdffile 10000 10 $datfile
    createRepNumFile $datfile repNum $prob($i) $repLim $percent $outfile

    set cdffile "../cdf/CDF_data-mining.tcl"
    set datfile "../cdf/data-mining.dat"
    set outfile "../cdf/repnum-data-$repLim-$prob($i).dat"
    #createFlowSize $cdffile 10000 10 $datfile

    createRepNumFile $datfile repNum $prob($i) $repLim $percent $outfile
}

#set SL 100
#set filenm "cdf/web-search.dat"
#set outfile "cdf/web-stat.dat"
#set threshold [getPara $filenm $SL pi]
#set threshold [expr $percent*$threshold]
#puts "$threshold"
#set fd [open $outfile w]
#for {set i 1} {$i <= $SL} {incr i} {
    #puts $fd "$pi($i)"
#}
#close $fd


#set filenm "cdf/data-mining.dat"
#set outfile "cdf/data-stat.dat"
#set threshold [getPara $filenm $SL pi]
#set threshold [expr $percent*$threshold]
#puts "$threshold"
#set fd [open $outfile w]
#for {set i 1} {$i <= $SL} {incr i} {
    #puts $fd "$pi($i)"
#}
#close $fd
