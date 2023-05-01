#include <stdio.h>
#include <stdlib.h>
#include "values.h"
#include "print.h"
#include "runtime.h"

FILE* in;
FILE* out;
val_t *heap;

int main(int argc, char** argv)
{

	int exit;
  in = stdin;
  out = stdout;
  heap = malloc(8 * heap_size);

  val_t result;

  result = entry(heap);

  exit = print_result(result);
  if (val_typeof(result) != T_VOID)
    putchar('\n');

  free(heap);

  return exit;
}
