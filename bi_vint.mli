(* $Id$ *)

(**
   Vint: variable-length representation of integers.
   
   Vints are a variable-length, byte-aligned representation of
   positive integers.
   
   A vint is represented by a sequence of n bytes from least significant
   to most significant. In all the bytes except the last one, the
   high bit is set to 1 and indicates that more bytes follow.
   The high bit of the last byte is set to 0.
   The remaining 7 bits in each byte represent data.

   Here is the representation of sample values:
{v
         0xxxxxxx
0        00000000
1        00000001
2        00000010
127      01111111

         1xxxxxxx 0xxxxxxx
128      10000000 00000001
129      10000001 00000001
255      11111111 00000001
256      11111111 00000010
16383    11111111 01111111

         1xxxxxxx 1xxxxxxx 0xxxxxxx
16384    10000000 10000000 00000001
16385    10000001 10000000 00000001
v}

   Positive integers can be represented by standard vints.
   We call this representation unsigned vint or uvint.

   Arbitrary integers can also be represented using vints, after mapping
   to positive integers. We call this representation signed vint or svint.
   Positive numbers and 0 are mapped to even numbers and negative numbers
   are mapped to odd positive numbers. Here is the mapping for
   small numbers:
{v
  signed   unsigned     vint
                      0xxxxxx0
    0         0       00000000
    1         2       00000010
    2         4       00000100
    3         6       00000110

                      0xxxxxx1
   -1         1       00000001
   -2         3       00000011
   -3         5       00000101
v}

  @see <http://lucene.apache.org/java/2_4_0/fileformats.html#VInt>
   Lucene VInt specification
*)

val uvint_of_int : ?buf:Bi_outbuf.t -> int -> string
val svint_of_int : ?buf:Bi_outbuf.t -> int -> string

val int_of_uvint : string -> int
val int_of_svint : string -> int

val write_uvint : Bi_outbuf.t -> int -> unit
val write_svint : Bi_outbuf.t -> int -> unit

val read_uvint : Bi_inbuf.t -> int
val read_svint : Bi_inbuf.t -> int
