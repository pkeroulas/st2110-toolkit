CC=gcc

reader: socket_reader.c
	$(CC) -std=c99 -o $@ $^
