exec >log
>log
for (( i = 4; i < 20; )); do
    ./mt_test $i 0 >> log
    let i=i+2
done
