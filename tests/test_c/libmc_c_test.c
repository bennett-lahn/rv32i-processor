#include "libmc.h"
#include "base.h"

// Recursive factorial function to test recursion
int factorial(int n) {
    if(n <= 1)
        return 1;
    else
        return n * factorial(n - 1);
}

int main(void) {
    int i, sum = 0;
    
    // --- Test Arithmetic and Loop Control ---
    // Calculate the sum of 1 through 10.
    for(i = 1; i <= 10; i++) {
        sum += i;
    }
    // Expected: 55
    printf("Sum of 1 to 10 is %d\n", sum);
    if(sum == 55)
        puts("Arithmetic loop test passed.\n"); // puts writes string to simulated I/O memory port
    else
        puts("Arithmetic loop test FAILED.\n");

    // --- Test Recursion ---
    int fact5 = factorial(5);
    // Expected: 120
    printf("Factorial of 5 is %d\n", fact5);

    // --- Test If/Else and Switch ---
    int x = 3;
    if(x == 3) {
        puts("If/Else test: x is 3, PASSED\n");
    } else {
        puts("If/Else test: x is not 3, FAILED\n");
    }
    switch(x) {
        case 1:
            puts("Switch test: x is 1, FAILED\n");
            break;
        case 2:
            puts("Switch test: x is 2, FAILED\n");
            break;
        case 3:
            puts("Switch test: x is 3, PASSED\n");
            break;
        default:
            puts("Switch test: x is unknown, FAILED\n");
    }

    // --- Test String Manipulation ---
    char str[50];
    // Use sprintf to initialize the string.
    sprintf(str, "Hello, RISC-V!\n");
    puts(str);
    int len = strlen(str);
    printf("String length is %d\n", len); // Expected: 15 for "Hello, RISC-V!\n"
    
    // Reverse the string and print it.
    char rev[50];
    // Use sprintf to copy str into rev.
    sprintf(rev, "%s", str);
    reverse_string(rev);
    printf("Reversed string: %s\n", rev);

    // --- Test Tokenization with strtok ---
    char tokens[50] = "one,two,three";
    char *tok = strtok(tokens, ",");
    while(tok != NULL) {
        printf("Token: %s\n", tok);
        tok = strtok(NULL, ",");
    }

    // --- Test Conversions (atoi and itoa) ---
    char numStr[20] = "1234";
    int num = atoi(numStr);
    printf("Converted '%s' to integer: %d\n", numStr, num);
    char outStr[20];
    itoa(num * 2, outStr);
    // Expected: "2468"
    printf("Converted %d back to string: %s\n", num * 2, outStr);

    // // --- Test Pointer Usage ---
    // int testVal = 42;
    // use_ptr(&testVal);
    // // The function use_ptr() is expected to have some observable effect; 
    // // we print testVal to see that the pointer was passed correctly.
    // printf("After use_ptr, testVal = %d\n", testVal);

    // --- Test memset and strcmp ---
    char buffer[20];
    memset(buffer, (int) 'a', 10);
    buffer[10] = '\0';
    printf("Buffer after memset: %s\n", buffer);
    if(strcmp(buffer, "aaaaaaaaaa") == 0)
        puts("Memset/strcmp test passed.\n");
    else
        puts("Memset/strcmp test FAILED.\n");

    // --- Test a simple switch-case with arithmetic ---
    int y = 10;
    switch(y) {
        case 1:
            printf("y is 1, FAILED\n");
            break;
        case 2:
            printf("y is 2, FAILED\n");
            break;
        default:
            printf("y is unknown, PASSED\n");
    }
}
