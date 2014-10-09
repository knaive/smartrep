all : find_cycle mt_test
.PHONY : all
find_cycle : crc.o find_cycle.o
	cc -o find_cycle crc.o find_cycle.o -g
mt_test : crc.o mt_test.o
	cc -o mt_test crc.o mt_test.o -lpthread -g
mt_test.o : mt_test.c
	cc -c mt_test.c -g
crc.o : crc.c
	cc -c crc.c -g
find_cycle.o : find_cycle.c
	cc -c find_cycle.c -g
clean :
	rm crc.o find_cycle.o find_cycle mt_test mt_test.o
