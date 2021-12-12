#include "io.h"

int gcd(int x, int y) {
  if (x%y == 0) return y;
  else return gcd(y, x%y);
}

int main() {
    int a=gcd(10,1);
    if (a==1)print("a");
    int b=gcd(34986,3087);
    if (b==1029)print("b");
    int c=gcd(2907,1539);
    if (c==171)print("c");

    return 0;
}

// int main () {
//     outl(16);
//     return 0;
// }