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

pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
unsigned short crc16_ccitt(const void *buf, int len);

void compare(unsigned short beg_port, unsigned short end_port, ip_addr src, ip_addr dst)
{
    int sport, dport;
    for (sport = beg_port+1; sport < end_port; ++sport){
        for (dport = beg_port+1; dport < end_port; ++dport){
            tuple t1;
            t1.proto = 6;
            t1.srcip.ipaddr = src;
            t1.dstip.ipaddr = dst;
            t1.srcPort = sport;
            t1.dstPort = dport;

            tuple t2 = t1;
            t2.dstPort++;

            int crc16_equal = ((crc16_ccitt(&t1,sizeof(tuple))/R16) == (crc16_ccitt(&t2,sizeof(tuple))/R16));
            int crc32_equal = ((crc32(0xffffffff,&t1,sizeof(tuple))/R32) == (crc32(0xffffffff,&t2,sizeof(tuple))/R32));
            if (pthread_mutex_lock(&mutex) != 0) {
                perror("pthread_mutex_lock");
                exit(EXIT_FAILURE);
            }
            num += 1;
            eq_num16 += crc16_equal;
            eq_num32 += crc32_equal;
            if (pthread_mutex_unlock(&mutex) != 0) {
                perror("pthread_mutex_unlock");
                exit(EXIT_FAILURE);
            }
        }
    }
}

typedef struct pair{
    unsigned short beg_port;
    unsigned short end_port;
} pair;
void loop(void* q)
{
    unsigned char b, c, d, f, g, h;
    pair *p = (pair *)q;
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
                            compare(p->beg_port, p->end_port, src, dst);
                        }
                    }
                }
            }
        }
    }
    pthread_exit(NULL);
}

int main(int argc, char *argv[])
{
    if (argc != 3) {
        printf("Wrong Arguments! \n");
        return 1;
    }
    printf("sizeof(ipaddr)=%d\n",sizeof(tuple));

    int k = atoi(argv[1]);
    int flag = atoi(argv[2]);
    R16 = (((unsigned short)(-1))/k+1);
    R32 = (((unsigned int)(-1))/k+1);
    printf("k = %d\n", k);
    printf("R16: %d, R32: %d\n", R16, R32);

    if (flag) {
        return 0;
    }


    int ret = 0, i, step = (port_end-port_beg)/THREAD_NUM;
    pthread_t ids[THREAD_NUM];
    pair p;
    for (i = 0; i < THREAD_NUM; ++i) {
        p.beg_port = port_beg + i*step;
        p.end_port = p.beg_port + step;
        ret = pthread_create(ids+i, NULL, (void*)loop, (void *)&p);
        if(ret) {
            printf("Thread Creation Failed!\n");
            exit(1);
        }
    }
    for (i = 0; i < THREAD_NUM; ++i) {
        pthread_join(ids[i], NULL);
    }

    printf("%lf, %lf, %lf, CRC16: %lf, CRC32: %lf\n",num,eq_num16,eq_num32,eq_num16/num, eq_num32/num);
    printf("Simulation Finished!\n");

    return 0;
}
