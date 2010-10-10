(* $Id$ *)

(**/**)

module Wr :
sig
  type tbl
  val create : int -> tbl
  val clear : tbl -> unit

  val put : tbl -> 'a -> int -> int
    (** [put tbl x pos] returns 0 if [x] is not already in the table
	and adds [x] to the table.  [pos] is the absolute position 
	of the first byte of the ref value excluding its tag.
	If [x] is found in the table, then the difference between
	[pos] and the original position is returned.
    *)
end

module Rd :
sig
  type 'a tbl
  val create : int -> 'a tbl
  val clear : 'a tbl -> unit

  val put : 'a tbl -> int -> 'a -> unit
    (** [put tbl pos x] puts the position of a new shared value into the
	table.  [pos] is the absolute position of the first byte
	of the ref value excluding its tag. *)

  val get : 'a tbl -> int -> 'a
    (** [get tbl pos] returns the value stored at this position
	or raises a {!Bi_util.Error} exception. *)
end

