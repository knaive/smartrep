#include "crc.h"
#include <string.h>
#include <stdio.h>
/*extern unsigned short crc16_ccitt(const void *buf, int len);*/

typedef struct tuple {
    unsigned int src_ip;
    unsigned int dst_ip;
    unsigned short proto;
    unsigned short src_port;
    unsigned short dst_port;
} tuple;

int main(int argc, char *argv[])
{
    if (argc != 2) {
        printf("Arguments Wrong!\n");
        return;
    }
    int num = atoi(argv[1]);
    int R16 =  (((unsigned short)(-1))/num+1);
    int R32 = (((unsigned int)(-1))/num+1);
    tuple tup;
    memset(&tup, 0, sizeof(tup));
    tup.src_ip = 10;
    tup.dst_port = 1024;
    unsigned short i = 0, max = (unsigned short)(-1);
    while(i<max) {
        tup.dst_port++;
        printf("crc16: %d\n", crc16_ccitt(&tup, sizeof(tup))/R16);
        printf("crc32: %d\n", crc32(0xffffffff, &tup, sizeof(tup))/R32);
        i++;
    }
    return 0;
}
