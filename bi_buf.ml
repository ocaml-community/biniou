(* $Id$ *)

(* "Unsafe" buffer type *)

type t = {
  mutable s : string;
  mutable len : int;
  init_len : int
}

let create n = {
  s = String.create n;
  len = 0;
  init_len = n
}

(*
  Guarantee that the buffer string has enough room for n additional bytes
  by reallocating a larger buffer string if needed.
*)
let extend b n =
  let slen0 = String.length b.s in
  let reqlen = b.len + n in
  if slen0 < reqlen then
    let slen =
      let x = 2 * slen0 in
      if x <= Sys.max_string_length then x
      else
	if Sys.max_string_length < reqlen then
	  invalid_arg "Buf.extend: reached Sys.max_string_length"
	else
	  Sys.max_string_length
    in
    let s = String.create slen in
    String.blit b.s 0 s 0 b.len;
    b.s <- s

(*
  Add n arbitrary bytes to the buffer and return the first position
  of the allocated substring.
*)
let alloc b n =
  extend b n;
  let pos = b.len in
  b.len <- pos + n;
  pos

let add_string b s =
  let len = String.length s in
  extend b len;
  String.blit s 0 b.s b.len len;
  b.len <- b.len + len

let add_char b c =
  let pos = alloc b 1 in
  b.s.[pos] <- c

let unsafe_add_char b c =
  let len = b.len in
  b.s.[len] <- c;
  b.len <- len + 1


let clear b = b.len <- 0

let reset b =
  if String.length b.s <> b.init_len then
    b.s <- String.create b.init_len;
  b.len <- 0
  
let contents b = String.sub b.s 0 b.len
