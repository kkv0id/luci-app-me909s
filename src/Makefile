all: sendat

clean:
	rm -f sendat *.o

sendat: main.o openDev.o
	$(CC) $(CFLAGS) -o $@ $^ -lpthread
