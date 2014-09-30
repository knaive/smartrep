all : test find_cycle mt_test
.PHONY : all
test : crc.o test-hash.o
	cc -o test crc.o test-hash.o
find_cycle : crc.o find_cycle.o
	cc -o find_cycle crc.o find_cycle.o
mt_test : crc.o mt_test.o
	cc -o mt_test crc.o mt_test.o -lpthread
mt_test.o : mt_test.c
	cc -c mt_test.c
crc.o : crc.c
	cc -c crc.c
test-hash.o : test-hash.c
	cc -c test-hash.c
find_cycle.o : find_cycle.c
	cc -c find_cycle.c
clean :
	rm test crc.o test-hash.o find_cycle.o test find_cycle mt_test mt_test.o
