#include "io.h"
int main()
{
   int a = clock();
   a = a + 1;
//   sleep(1) ;
   int b = clock() ;
    print("hello\n") ;
    outlln(b-a) ;
    return 0; // check actual running time
}