(* $Id$ *)

type node_tag = int

val bool_tag : node_tag (* 0 *)
val int8_tag : node_tag (* 1 *)
val int16_tag : node_tag (* 2 *)
val int32_tag : node_tag (* 3 *)
val int64_tag : node_tag (* 4 *)
val int128_tag : node_tag (* 5 *)
val float64_tag : node_tag (* 12 *)
val uvint_tag : node_tag (* 16 *)
val svint_tag : node_tag (* 17 *)
val string_tag : node_tag (* 18 *)
val array_tag : node_tag (* 19 *)
val tuple_tag : node_tag (* 20 *)
val record_tag : node_tag (* 21 *)
val num_variant_tag : node_tag (* 22 *)
val variant_tag : node_tag (* 23 *)
val record_table_tag : node_tag (* 25  *)

type hash = int (* 31 bits *)
val hash_name : string -> hash
val write_hashtag : Bi_buf.t -> hash -> bool -> unit
val string_of_hashtag : hash -> bool -> string
val read_hashtag : 
  string -> int ref ->
  (string -> int ref -> hash -> bool -> 'a) -> 'a

val read_field_hashtag : string -> int ref -> hash

val make_unhash : string list -> (int -> string option)

type int7 = int
val write_numtag : Bi_buf.t -> int7 -> bool -> unit
val read_numtag :
  string -> int ref ->
  (string -> int ref -> int7 -> bool -> 'a) -> 'a

val write_tag : Bi_buf.t -> node_tag -> unit
val write_untagged_bool : Bi_buf.t -> bool -> unit
val write_untagged_char : Bi_buf.t -> char -> unit
val write_untagged_int8 : Bi_buf.t -> int -> unit
val write_untagged_int16 : Bi_buf.t -> int -> unit
val write_untagged_int32 : Bi_buf.t -> int32 -> unit
val write_untagged_int64 : Bi_buf.t -> int64 -> unit
val write_untagged_int128 : Bi_buf.t -> string -> unit
val write_untagged_float64 : Bi_buf.t -> float -> unit
val write_untagged_string : Bi_buf.t -> string -> unit
val write_untagged_uvint : Bi_buf.t -> int -> unit
val write_untagged_svint : Bi_buf.t -> int -> unit

val write_bool : Bi_buf.t -> bool -> unit
val write_char : Bi_buf.t -> char -> unit
val write_int8 : Bi_buf.t -> int -> unit
val write_int16 : Bi_buf.t -> int -> unit
val write_int32 : Bi_buf.t -> int32 -> unit
val write_int64 : Bi_buf.t -> int64 -> unit
val write_int128 : Bi_buf.t -> string -> unit
val write_float64 : Bi_buf.t -> float -> unit
val write_string : Bi_buf.t -> string -> unit
val write_uvint : Bi_buf.t -> int -> unit
val write_svint : Bi_buf.t -> int -> unit

val read_tag : string -> int ref -> node_tag
val read_untagged_bool : string -> int ref -> bool
val read_untagged_char : string -> int ref -> char
val read_untagged_int8 : string -> int ref -> int
val read_untagged_int16 : string -> int ref -> int
val read_untagged_int32 : string -> int ref -> int32
val read_untagged_int64 : string -> int ref -> int64
val read_untagged_int128 : string -> int ref -> string
val read_untagged_float64 : string -> int ref -> float
val read_untagged_string : string -> int ref -> string
val read_untagged_uvint : string -> int ref -> int
val read_untagged_svint : string -> int ref -> int

val skip : string -> int ref -> unit
  (* read and discard a value (useful for skipping unknown record fields) *)

type tree =
    [
    | `Bool of bool
    | `Int8 of int
    | `Int16 of int
    | `Int32 of Int32.t
    | `Int64 of Int64.t
    | `Int128 of string (* big endian, string length must be exactly 16 *)
    | `Float64 of float
    | `Uvint of int
    | `Svint of int
    | `String of string
    | `Array of (node_tag * tree array) option
    | `Tuple of tree array
    | `Record of (string option * hash * tree) array
    | `Num_variant of (int * tree option)
    | `Variant of (string option * hash * tree option)
    | `Record_table of 
	((string option * hash * node_tag) array * tree array array) option ]
  (* Tree representing serialized data, useful for testing
     and for untyped transformations. *)

val string_of_tree : tree -> string
  (* Testing *)

val tree_of_string : ?unhash:(hash -> string option) -> string -> tree
  (* Testing *)

val view :
  ?unhash:(hash -> string option) -> string -> string
val print_view :
  ?unhash:(hash -> string option) -> string -> unit
val output_view :
  ?unhash:(hash -> string option) -> out_channel -> string -> unit
  (* Print human-readable representation of the data *)
