#include "crc.h"
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#pragma pack(1)
#define THREAD_NUM 22
int port_beg = 1024, port_end = 65000;
int pod = 4, sw = 2, host = 4;
double num = 0, eq_num16 = 0, eq_num32 = 0;
int R16 = 0, R32 = 0;

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
    unsigned char proto;
} tuple;


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

    return 0;
}
