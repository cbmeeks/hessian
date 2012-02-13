#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv)
{
  int val;
  FILE *in;
  FILE *out;
  char cmd[256];
  if (argc < 3) printf("Invokes exomizer2 (forward mode + literals), strips startaddress from header\nUsage: pack2 <infile> <outfile>\n");
  
  sprintf(cmd, "exomizer2 level -f -o%s %s@0", "temp.bin", argv[1]);
  val = system(cmd);
  if (val > 0) return val;

  in = fopen("temp.bin", "rb");
  if (!in) return 1;
  out = fopen(argv[2], "wb");
  if (!out) return 1;
  // Skip first 2 bytes of exomized output
  fgetc(in);
  fgetc(in);
  for (;;)
  {
    int c = fgetc(in);
    if (c == EOF) break;
    fputc(c, out);
  }
  fclose(in);
  fclose(out);
  unlink("temp.bin");
  return 0;
}
