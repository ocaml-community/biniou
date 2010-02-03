(* $Id$ *)

(*
  http://lucene.apache.org/java/2_4_0/fileformats.html#VInt

  VInt

  A variable-length format for positive integers is defined where the
  high-order bit of each byte indicates whether more bytes remain to
  be read. The low-order seven bits are appended as increasingly more
  significant bits in the resulting integer value. Thus values from
  zero to 127 may be stored in a single byte, values from 128 to
  16,383 may be stored in two bytes, and so on.

  VInt Encoding Example:

  Value    1st byte  2nd byte  3rd byte 

  0        00000000  
  1        00000001  
  2        00000010  
  ...  
  127      01111111  
  128      10000000  00000001  
  129      10000001  00000001  
  130      10000010  00000001  
  ...  
  16,383   11111111  01111111  
  16,384   10000000  10000000  00000001 
  16,385   10000001  10000000  00000001 
  ...  

*)

(*
  uvint = unsigned vint, encodes an unsigned int (standard vint)
  svint = signed vint, the low bit of the int being used as a sign bit
          (all ints except min_int are supported)
*)

val uvint_of_int : ?buf:Bi_buf.t -> int -> string
val svint_of_int : ?buf:Bi_buf.t -> int -> string

val int_of_uvint : string -> int
val int_of_svint : string -> int

val write_uvint : Bi_buf.t -> int -> unit
val write_svint : Bi_buf.t -> int -> unit

val read_uvint : string -> int ref -> int
val read_svint : string -> int ref -> int
