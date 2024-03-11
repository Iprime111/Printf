#include <cstdio>

extern int printf_custom (char *str, ...);

int main () {
    int testPrintedSymbols = 0;

    int printedSymbols = printf_custom ("%c ppp%n %s %x %o %b %u %d\n", 'e', &testPrintedSymbols, "hui", 0xfba7682c, -1, 0b11, 773498893, -68654129);

    printf ("Total symbols: %d\n%%n result: %d\n", printedSymbols, testPrintedSymbols);

    return 0;
}
