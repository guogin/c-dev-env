#include <stdio.h>
#include "utils.h"

int main(int argc, char *argv[]) {
    printf("Test Application\n");
    printf("argc = %d\n", argc);

    int result = add(10, 32);
    printf("10 + 32 = %d\n", result);

    int arr[] = {1, 2, 3, 4, 5};
    print_array(arr, 5);

    // 设置断点在这里测试调试
    int x = 42;
    printf("x = %d\n", x);

    return 0;
}