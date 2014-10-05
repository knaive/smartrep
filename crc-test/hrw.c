/*
 *highest random weight
 *input: tuples  = (srcip, dstip, srcport, dstport, ip addresses of N available nexthops)
 *output: ip address of next hop
 *algorithm: max_{i=1}^{i=n}hash(tuple_i)
 *
 */
