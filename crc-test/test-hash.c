#include "crc.h"
#include <stdio.h>
#include <stdlib.h>
#pragma pack(1)
unsigned short crc16_ccitt(const void *buf, int len);
int R16, R32;
int port_beg = 1024, port_end = 2500;
int pod = 4, sw = 2, host = 4;

typedef struct ip_addr{
    unsigned char a;
    unsigned char b;
    unsigned char c;
    unsigned char d;
} ip_addr;

typedef struct tuple {
    union {
        ip_addr ipaddr;
        unsigned int ip;
    } srcip;
    union {
        ip_addr ipaddr;
        unsigned int ip;
    } dstip;
    unsigned short srcPort;
    unsigned short dstPort;
    unsigned short proto;
} tuple;

int compare(unsigned short begin_port, unsigned short end_port, ip_addr src, ip_addr dst, double *eq_num16, double *eq_num32)
{
    int num = 0, sport, dport;
    for (sport = begin_port; sport < end_port; ++sport){
        for (dport = begin_port; dport < end_port; ++dport){
            tuple t1;
            t1.proto = 6;
            t1.srcip.ipaddr = src;
            t1.dstip.ipaddr = dst;
            t1.srcPort = sport;
            t1.dstPort = dport;

            tuple t2 = t1;
            t2.dstPort++;

            num += 1;
            int crc16_equal = ((crc16_ccitt(&t1,sizeof(tuple))/R16) == (crc16_ccitt(&t2,sizeof(tuple))/R16));
            int crc32_equal = ((crc32(0xffffffff,&t1,sizeof(tuple))/R32) == (crc32(0xffffffff,&t2,sizeof(tuple))/R32));
            /*if (crc16_equal) printf("%d,%d,%d,%d,%d\n",t1.srcip.ip, t1.dstip.ip, t1.proto, t1.srcPort, t1.dstPort);*/
            /*if (crc32_equal) printf("%d,%d,%d,%d,%d\n",t1.srcip.ip, t1.dstip.ip, t1.proto, t1.srcPort, t1.dstPort);*/
            *eq_num16 += crc16_equal;
            *eq_num32 += crc32_equal;
        }
    }
    return num;
}

int main(int argc, char *argv[])
{
    if (argc != 2) {
        printf("Wrong Arguments! \n");
        return 1;
    }
    printf("sizeof(ipaddr)=%d\n",sizeof(tuple));

    int k = atoi(argv[1]);
    R16 = (((unsigned short)(-1))/k+1);
    R32 = (((unsigned int)(-1))/k+1);
    printf("k = %d\n", k);
    printf("R16: %d, R32: %d\n", R16, R32);

    double num = 0, eq_num16 = 0, eq_num32 = 0;
    unsigned char b, c, d, f, g, h;

    for (b = 0; b < pod; ++b){
        for (c = 0; c < sw; ++c){
            for (d = 2; d < host; ++d){
                ip_addr src;
                src.a = 10;
                src.b = b;
                src.c = c;
                src.d = d;

                for (f = 0; f < pod; ++f){
                    for (g = 0; g < sw; ++g){
                        for (h = 2; h < host; ++h){
                            ip_addr dst = src;
                            dst.b = f;
                            dst.c = g;
                            dst.d = h;
                            if (!(b-f) && !(c-g) && !(d-h)) continue;
                            num += compare(port_beg, port_end, src, dst, &eq_num16, &eq_num32);
                        }
                    }
                }
            }
        }
    }
    printf("%lf, %lf, %lf, CRC16: %lf, CRC32: %lf\n",num,eq_num16,eq_num32,eq_num16/num, eq_num32/num);

    return 0;
}
