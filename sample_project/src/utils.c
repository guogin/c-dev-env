#include "utils.h"
#include <stdio.h>

int add(int a, int b) {
    return a + b;
}

void print_array(int *arr, int size) {
    printf("Array: [");
    for (int i = 0; i < size; i++) {
        printf("%d", arr[i]);
        if (i < size - 1) printf(", ");
    }
    printf("]\n");
}