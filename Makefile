AssemblySources = printf.s
CppSources		= main.cpp
ObjectFiles		= main.o printf.o
OutputFile		= printf

.PHONY: all clean

all: 
	@@nasm -felf64 $(AssemblySources)
	@@gcc -Wall -Wno-write-strings -c $(CppSources)
	@@gcc -no-pie $(ObjectFiles) -o $(OutputFile)

clean:
	rm $(ObjectFiles)
	rm $(OutputFile)
