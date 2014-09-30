#!/bin/sh

ecp_num="4 8 16 64"
dat_dir="dat"
for num in ${ecp_num}
do
    ./find_cycle $num > $dat_dir/log-$num
    grep crc16 $dat_dir/log-$num > $dat_dir/crc16-$num
    grep crc32 $dat_dir/log-$num > $dat_dir/crc32-$num
done

