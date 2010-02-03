(* $Id$ *)

(* Variable-byte encoding of 8-byte integers (starting from 0). *)

open Printf
open Bi_buf

let unsigned_of_signed i =
  if i >= 0 then i lsl 1
  else
    if i = min_int then
      invalid_arg "Bi_vint.unsigned_of_signed: min_int"
    else
      ((-i) lsl 1) lor 1

let signed_of_unsigned i =
  if i land 1 = 0 then i lsr 1
  else - (i lsr 1)

let write_uvint buf i  =
  Bi_buf.extend buf 9; (* makes room for at most 9 bytes *)

  let x = ref i in
  while !x lsr 7 <> 0 do
    let byte = 0x80 lor (!x land 0x7f) in
    Bi_buf.unsafe_add_char buf (Char.chr byte);
    x := !x lsr 7;
  done;
  Bi_buf.unsafe_add_char buf (Char.chr !x)
    
let write_svint buf i =
  write_uvint buf (unsigned_of_signed i)
    
(* convenience *)
let uvint_of_int ?buf i =
  let buffer = 
    match buf with
      | None -> Bi_buf.create 10 
      | Some b -> b
  in
  Bi_buf.clear buffer;
  write_uvint buffer i;
  Bi_buf.contents buffer

let svint_of_int ?buf i =
  uvint_of_int ?buf (unsigned_of_signed i)

let get s i =
  if i >= 0 && i < String.length s then String.unsafe_get s i
  else
    Bi_util.error "Bi_vint.read_int: corrupted data"


let read_uvint s pos =
  let rec aux s pos x =
    let b = Char.code (get s !pos) in
    incr pos;
    if b >= 0x80 then
      (b land 0x7f) lor ((aux s pos x) lsl 7)
    else
      b
  in
  aux s pos 0

let read_svint s pos =
  signed_of_unsigned (read_uvint s pos)

(* convenience *)
let int_of_uvint s = read_uvint s (ref 0)
let int_of_svint s = read_svint s (ref 0)

let rec read_list s pos =
  if !pos < String.length s then
    let x = read_uvint s pos in
    x :: read_list s pos
  else
    []

let test () =
  List.iter (
    fun i -> 
      printf "%i %x\n%s\n" i i
	(Bi_util.print_bits (Bi_util.string8_of_int i))
  )
    (read_list "\128\000\255\255\255\127" (ref 0))

(*
let _ = test ()
*)
