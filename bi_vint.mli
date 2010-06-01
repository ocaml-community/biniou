(* $Id$ *)

(**
   Vint: variable-length representation of integers
   
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
    vint              unsigned	            signed        
    representation    interpretation	    interpretation
		      (uvint)               (svint)	
    0xxxxxx0		
    00000000          0	             	    0
    00000010          2	             	    1
    00000100          4	                    2
    00000110          6	                    3
				
    0xxxxxx1	  						
    00000001          1	                    -1
    00000011          3	                    -2
    00000101          5                     -3
v}

   @see <http://lucene.apache.org/java/2_4_0/fileformats.html#VInt>
   Lucene VInt specification
*)


(**
   This module currently provides only conversions between vint and the
   OCaml int type. Here are the current limits of OCaml ints on
   32-bit and 64-bit systems:
{v
   word length (bits)                 32          64

   int length (bits)                  31          63

   min_int (lowest signed int)        0x40000000  0x4000000000000000
                                      -1073741824 -4611686018427387904

   max_int (greatest signed int)      0x3fffffff  0x3fffffffffffffff
                                      1073741823  4611686018427387903

   lowest unsigned int                0x0         0x0
                                      0           0

   greatest unsigned int              0x7fffffff  0x7fffffffffffffff
                                      2147483647  9223372036854775807

   maximum vint length (data bits)    31          63
   maximum vint length (total bytes)  5           9
v}
*)

type uint = int
  (** Unsigned int.
      Note that ints (signed) and uints use the same representation
      for integers within \[0, [max_int]\].
  *)

val uvint_of_uint : ?buf:Bi_outbuf.t -> uint -> string
  (** Convert an unsigned int to a vint.
      @param buf existing output buffer that could be reused by this function
      instead of creating a new one. *)

val svint_of_int : ?buf:Bi_outbuf.t -> int -> string
  (** Convert a signed int to a vint.
      @param buf existing output buffer that could be reused by this function
      instead of creating a new one. *)

val uint_of_uvint : string -> uint
  (** Interpret a vint as an unsigned int.
      @raise Bi_util.Error if the input string is not a single valid uvint
      that is representable using the uint type. *)

val int_of_svint : string -> int
  (** Interpret a vint as a signed int.
      @raise Bi_util.Error if the input string is not a single valid svint
      that is representable using the int type. *)

val write_uvint : Bi_outbuf.t -> uint -> unit
  (** Write an unsigned int to a buffer. *)

val write_svint : Bi_outbuf.t -> int -> unit
  (** Write a signed int to a buffer. *)

val read_uvint : Bi_inbuf.t -> uint
  (** Read an unsigned int from a buffer.
      @raise Bi_util.Error if there is no data to read from or if the
      uvint is not representable using the uint type. *)

val read_svint : Bi_inbuf.t -> int
  (** Read a signed int from a buffer.
      @raise Bi_util.Error if there is no data to read from or if the
      svint is not representable using the int type. *)
