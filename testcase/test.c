#include "io.h"
int main()
{
    outlln(1);
    int a = clock();
    outlln(1);
    sleep(10000); // sleep for 10s
    outlln(1);
    int b = clock();
    outlln(1);
    outlln(b-a);
    outlln((b-a)/CPU_CLK_FREQ); // should be 10
    return 0; // check actual running time
}