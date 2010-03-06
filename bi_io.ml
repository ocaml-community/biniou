(* $Id$ *)

open Printf

open Bi_buf

type node_tag = int

let bool_tag = 0
let int8_tag = 1
let int16_tag = 2
let int32_tag = 3
let int64_tag = 4
let int128_tag = 5
let float64_tag = 12
let uvint_tag = 16
let svint_tag = 17
let string_tag = 18
let array_tag = 19
let tuple_tag = 20
let record_tag = 21
let num_variant_tag = 22
let variant_tag = 23
let tuple_table_tag = 24
let record_table_tag = 25 
let matrix_tag = 26

type hash = int

(*
  Data tree, for testing purposes.
*)
type tree =
    [ `Bool of bool
    | `Int8 of int
    | `Int16 of int
    | `Int32 of Int32.t
    | `Int64 of Int64.t
    | `Int128 of string
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
    
(* extend sign bit *)
let make_signed x =
  if x > 0x3FFFFFFF then x - (1 lsl 31) else x

(*
  Same function as the one used for OCaml variants and object methods.
*)
let hash_name s =
  let accu = ref 0 in
  for i = 0 to String.length s - 1 do
    accu := 223 * !accu + Char.code s.[i]
  done;
  (* reduce to 31 bits *)
  accu := !accu land (1 lsl 31 - 1);
  (* make it signed for 64 bits architectures *)
  make_signed !accu


(*
  Structure of a hashtag: 4 bytes,

  argbit 7bits 8bits 8bits 8bits
         +---------------------+
              31-bit hash

  argbit = 1 iff hashtag is followed by an argument, this is always 1 for
           record fields.

*)
let write_hashtag buf h has_arg =
  let h = h land 0x7fffffff in
  let pos = Bi_buf.alloc buf 4 in
  let s = buf.s in
  String.unsafe_set s (pos+3) (Char.chr (h land 0xff));
  let h = h lsr 8 in
  String.unsafe_set s (pos+2) (Char.chr (h land 0xff));
  let h = h lsr 8 in
  String.unsafe_set s (pos+1) (Char.chr (h land 0xff));
  let h = h lsr 8 in
  String.unsafe_set s pos (
    Char.chr (
      if has_arg then h lor 0x80
      else h
    )
  )

let string_of_hashtag h has_arg =
  let buf = Bi_buf.create 4 in
  write_hashtag buf h has_arg;
  Bi_buf.contents buf

let read_hashtag s pos cont =
  let i = !pos in
  if i + 4 > String.length s then
    Bi_util.error "Corrupted data (hashtag)";
  let x0 = Char.code s.[i] in
  let has_arg = x0 >= 0x80 in
  let x1 = (x0 land 0x7f) lsl 24 in
  let x2 = (Char.code s.[i+1]) lsl 16 in
  let x3 = (Char.code s.[i+2]) lsl 8 in
  let x4 = Char.code s.[i+3] in
  pos := !pos + 4;
  let h = make_signed (x1 lor x2 lor x3 lor x4) in
  
  cont s pos h has_arg


let read_field_hashtag s pos =
  let i = !pos in
  let i' = i + 4 in
  if i' > String.length s then
    Bi_util.error "Corrupted data (truncated field hashtag)";
  let x0 = Char.code (String.unsafe_get s i) in
  if x0 < 0x80 then
    Bi_util.error "Corrupted data (invalid field hashtag)";
  let x1 = (x0 land 0x7f) lsl 24 in
  let x2 = (Char.code (String.unsafe_get s (i+1))) lsl 16 in
  let x3 = (Char.code (String.unsafe_get s (i+2))) lsl 8 in
  let x4 = Char.code (String.unsafe_get s (i+3)) in
  pos := i';
  make_signed (x1 lor x2 lor x3 lor x4)
  

type int7 = int

let write_numtag buf i has_arg =
  if i < 0 || i > 0x7f then
    Bi_util.error "Corrupted data (invalid numtag)";
  let x =
    if has_arg then i lor 0x80
    else i
  in
  Bi_buf.add_char buf (Char.chr x)

let read_numtag s pos cont =
  if !pos >= String.length s then
    Bi_util.error "Corrupted data (numtag)";
  let x = Char.code s.[!pos] in
  incr pos;
  let has_arg = x >= 0x80 in
  cont s pos (x land 0x7f) has_arg

let make_unhash l =
  let tbl = Hashtbl.create (4 * List.length l) in
  List.iter (
    fun s ->
      let h = hash_name s in
      try 
	match Hashtbl.find tbl h with
	    Some s' ->
	      if s <> s' then
		failwith (
		  sprintf
		    "Bi_io.make_unhash: \
                     %S and %S have the same hash, please pick another name"
		    s s'
		)
	  | None -> assert false

      with Not_found -> Hashtbl.add tbl h (Some s)
  ) l;
  fun h ->
    try Hashtbl.find tbl h
    with Not_found -> None


let write_tag buf x =
  Bi_buf.add_char buf (Char.chr x)

let write_untagged_bool buf x =
  Bi_buf.add_char buf (if x then '\x01' else '\x00')

let write_untagged_char buf x =
  Bi_buf.add_char buf x

let write_untagged_int8 buf x =
  Bi_buf.add_char buf (Char.chr x)

let write_untagged_int16 buf x =
  Bi_buf.add_char buf (Char.chr (x lsr 8));
  Bi_buf.add_char buf (Char.chr (x land 0xff))

let write_untagged_int32 buf x =
  let high = Int32.to_int (Int32.shift_right_logical x 16) in
  Bi_buf.add_char buf (Char.chr (high lsr 8));
  Bi_buf.add_char buf (Char.chr (high land 0xff));
  let low = Int32.to_int x in
  Bi_buf.add_char buf (Char.chr ((low lsr 8) land 0xff));
  Bi_buf.add_char buf (Char.chr (low land 0xff))
    
let write_untagged_int64 buf x =
  let x4 = Int64.to_int (Int64.shift_right_logical x 48) in
  Bi_buf.add_char buf (Char.chr (x4 lsr 8));
  Bi_buf.add_char buf (Char.chr (x4 land 0xff));
  let x3 = Int64.to_int (Int64.shift_right_logical x 32) in
  Bi_buf.add_char buf (Char.chr ((x3 lsr 8) land 0xff));
  Bi_buf.add_char buf (Char.chr (x3 land 0xff));
  let x2 = Int64.to_int (Int64.shift_right_logical x 16) in
  Bi_buf.add_char buf (Char.chr ((x2 lsr 8) land 0xff));
  Bi_buf.add_char buf (Char.chr (x2 land 0xff));
  let x1 = Int64.to_int x in
  Bi_buf.add_char buf (Char.chr ((x1 lsr 8) land 0xff));
  Bi_buf.add_char buf (Char.chr (x1 land 0xff))


let float_endianness =
  match String.unsafe_get (Obj.magic 1.0) 0 with
      '\x3f' -> `Big
    | '\x00' -> `Little
    | _ -> assert false

let read_untagged_float64 s pos =
  let i = !pos in
  let i' = i + 8 in
  if i' > String.length s then
    failwith "Corrupted data (float64)";
  let x = Obj.new_block Obj.double_tag 8 in
  (match float_endianness with
       `Little ->
	 for j = 0 to 7 do
	   String.unsafe_set (Obj.obj x) (7-j) (String.unsafe_get s (i+j))
	 done
     | `Big ->
	 for j = 0 to 7 do
	   String.unsafe_set (Obj.obj x) j (String.unsafe_get s (i+j))
	 done
  );
  pos := i';
  (Obj.obj x : float)

let write_untagged_float64 buf x =
  let i = Bi_buf.alloc buf 8 in
  let s = buf.s in
  (match float_endianness with
       `Little ->
	 for j = 0 to 7 do
	   String.unsafe_set s (i+j) (String.unsafe_get (Obj.magic x) (7-j))
	 done
     | `Big ->
	 for j = 0 to 7 do
	   String.unsafe_set s (i+j) (String.unsafe_get (Obj.magic x) j)
	 done
  )

let () =
  let s = "\x3f\xf0\x06\x05\x04\x03\x02\x01" in
  let x = 1.00146962706651288 in
  let y = read_untagged_float64 s (ref 0) in
  if x <> y then
    assert false;
  let buf = Bi_buf.create 8 in
  write_untagged_float64 buf x;
  if Bi_buf.contents buf <> s then
    assert false



let write_untagged_string buf s =
  Bi_vint.write_uvint buf (String.length s);
  Bi_buf.add_string buf s

let write_untagged_int128 buf s =
  if String.length s <> 16 then
    invalid_arg "Bi_io.write_untagged_int128";
  Bi_buf.add_string buf s

let write_untagged_uvint = Bi_vint.write_uvint
let write_untagged_svint = Bi_vint.write_svint

let write_bool buf x =
  write_tag buf bool_tag;
  write_untagged_bool buf x

let write_char buf x =
  write_tag buf int8_tag;
  write_untagged_char buf x

let write_int8 buf x =
  write_tag buf int8_tag;
  write_untagged_int8 buf x

let write_int16 buf x =
  write_tag buf int16_tag;
  write_untagged_int16 buf x

let write_int32 buf x =
  write_tag buf int32_tag;
  write_untagged_int32 buf x

let write_int64 buf x =
  write_tag buf int64_tag;
  write_untagged_int64 buf x

let write_int128 buf x =
  write_tag buf int128_tag;
  write_untagged_int128 buf x

let write_float64 buf x =
  write_tag buf float64_tag;
  write_untagged_float64 buf x

let write_string buf x =
  write_tag buf string_tag;
  write_untagged_string buf x

let write_uvint buf x =
  write_tag buf uvint_tag;
  write_untagged_uvint buf x

let write_svint buf x =
  write_tag buf svint_tag;
  write_untagged_svint buf x




let rec write_tree buf tagged (x : tree) =
  match x with
      `Bool x ->
	if tagged then
	  write_tag buf bool_tag;
	write_untagged_bool buf x

    | `Int8 x ->
	if tagged then 
	  write_tag buf int8_tag;
	write_untagged_int8 buf x

    | `Int16 x ->
	if tagged then
	  write_tag buf int16_tag;
	write_untagged_int16 buf x

    | `Int32 x ->
	if tagged then
	  write_tag buf int32_tag;
	write_untagged_int32 buf x

    | `Int64 x ->
	if tagged then
	  write_tag buf int64_tag;
	write_untagged_int64 buf x

    | `Int128 x ->
	if tagged then
	  write_tag buf int128_tag;
	write_untagged_int128 buf x

    | `Float64 x ->
	if tagged then
	  write_tag buf float64_tag;
	write_untagged_float64 buf x

    | `Uvint x ->
	if tagged then
	  write_tag buf uvint_tag;
	Bi_vint.write_uvint buf x

    | `Svint x ->
	if tagged then
	  write_tag buf svint_tag;
	Bi_vint.write_svint buf x

    | `String s ->
	if tagged then
	  write_tag buf string_tag;
	write_untagged_string buf s

    | `Array o ->
	if tagged then
	  write_tag buf array_tag;
	(match o with
	     None -> Bi_vint.write_uvint buf 0
	   | Some (node_tag, a) ->
	       let len = Array.length a in
	       Bi_vint.write_uvint buf len;
	       if len > 0 then (
		 write_tag buf node_tag;
		 Array.iter (write_tree buf false) a
	       )
	)

    | `Tuple a ->
	if tagged then
	  write_tag buf tuple_tag;
	Bi_vint.write_uvint buf (Array.length a);
	Array.iter (write_tree buf true) a

    | `Record a ->
	if tagged then
	  write_tag buf record_tag;
	Bi_vint.write_uvint buf (Array.length a);
	Array.iter (write_field buf) a

    | `Num_variant (i, x) ->
	if tagged then
	  write_tag buf num_variant_tag;
	write_numtag buf i (x <> None);
	(match x with
	     None -> ()
	   | Some v -> write_tree buf true v)

    | `Variant (o, h, x) ->
	if tagged then
	  write_tag buf variant_tag;
	write_hashtag buf h (x <> None);
	(match x with
	     None -> ()
	   | Some v -> write_tree buf true v)

    | `Record_table o ->
	if tagged then
	  write_tag buf record_table_tag;
	(match o with
	     None -> Bi_vint.write_uvint buf 0
	   | Some (fields, a) ->
	       let row_num = Array.length a in
	       Bi_vint.write_uvint buf row_num;
	       if row_num > 0 then
		 let col_num = Array.length fields in
		 Bi_vint.write_uvint buf col_num;
		 Array.iter (
		   fun (name, h, tag) ->
		     write_hashtag buf h true;
		     write_tag buf tag
		 ) fields;
		 if row_num > 0 then (
		   for i = 0 to row_num - 1 do
		     let ai = a.(i) in
		     if Array.length ai <> col_num then
		       invalid_arg "Bi_io.write_tree: Malformed `Record_table";
		     for j = 0 to col_num - 1 do
		       write_tree buf false ai.(j)
		     done
		   done
		 )
	)


and write_field buf (s, h, x) =
  write_hashtag buf h true;
  write_tree buf true x

let string_of_tree x =
  let buf = Bi_buf.create 1000 in
  write_tree buf true x;
  Bi_buf.contents buf

let tag_error () =
  Bi_util.error "Corrupted data (tag)"

let read_tag s pos =
  let i = !pos in
  if i >= String.length s then
    tag_error ();
  let x = Char.code (String.unsafe_get s i) in
  pos := i + 1;
  x

let read_untagged_bool s pos =
  let i = !pos in
  if i >= String.length s then
    Bi_util.error "Corrupted data (bool)";
  let x =
    match s.[i] with
	'\x00' -> false
      | '\x01' -> true
      | _ -> Bi_util.error "Corrupted data (bool value)"
  in
  pos := i + 1;
  x

let read_untagged_char s pos =
  if !pos >= String.length s then
    Bi_util.error "Corrupted data (char)";
  let x = s.[!pos] in
  incr pos;
  x

let read_untagged_int8 s pos =
  if !pos >= String.length s then
    Bi_util.error "Corrupted data (int8)";
  let x = Char.code s.[!pos] in
  incr pos;
  x

let read_untagged_int16 s pos =
  let i = !pos in
  if i + 2 > String.length s then
    Bi_util.error "Corrupted data (int16)";
  let x = ((Char.code s.[i]) lsl 8) lor (Char.code s.[i+1]) in
  pos := !pos + 2;
  x

let read_untagged_int32 s pos =
  let i = !pos in
  if i + 4 > String.length s then
    Bi_util.error "Corrupted data (int32)";
  let x1 =
    Int32.of_int (((Char.code s.[i  ]) lsl 8) lor (Char.code s.[i+1])) in
  let x2 =
    Int32.of_int (((Char.code s.[i+2]) lsl 8) lor (Char.code s.[i+3])) in
  pos := !pos + 4;
  Int32.logor (Int32.shift_left x1 16) x2

let read_untagged_int64 s pos =
  let i = !pos in
  if i + 8 > String.length s then
    Bi_util.error "Corrupted data (int64)";
  let x1 =
    Int64.of_int (((Char.code s.[i  ]) lsl 8) lor (Char.code s.[i+1])) in
  let x2 =
    Int64.of_int (((Char.code s.[i+2]) lsl 8) lor (Char.code s.[i+3])) in
  let x3 =
    Int64.of_int (((Char.code s.[i+4]) lsl 8) lor (Char.code s.[i+5])) in
  let x4 =
    Int64.of_int (((Char.code s.[i+6]) lsl 8) lor (Char.code s.[i+7])) in
  pos := !pos + 8;
  Int64.logor (Int64.shift_left x1 48)
    (Int64.logor (Int64.shift_left x2 32)
       (Int64.logor (Int64.shift_left x3 16) x4))




let read_untagged_string s pos =
  let len = Bi_vint.read_uvint s pos in
  if !pos + len > String.length s then
    Bi_util.error "Corrupted data (string)";
  let str = String.sub s !pos len in
  pos := !pos + len;
  str

let read_untagged_int128 s pos =
  if !pos + 16 > String.length s then
    Bi_util.error "Corrupted data (int128)";
  let str = String.sub s !pos 16 in
  pos := !pos + 16;
  str

let read_untagged_uvint = Bi_vint.read_uvint
let read_untagged_svint = Bi_vint.read_svint

let read_bool s pos = `Bool (read_untagged_bool s pos)

let read_int8 s pos = `Int8 (read_untagged_int8 s pos)

let read_int16 s pos = `Int16 (read_untagged_int16 s pos)

let read_int32 s pos = `Int32 (read_untagged_int32 s pos)

let read_int64 s pos = `Int64 (read_untagged_int64 s pos)

let read_int128 s pos = `Int128 (read_untagged_int128 s pos)

let read_float s pos =
  `Float64 (read_untagged_float64 s pos)

let read_uvint s pos = `Uvint (read_untagged_uvint s pos)
let read_svint s pos = `Svint (read_untagged_svint s pos)

let read_string s pos = `String (read_untagged_string s pos)

let print s = print_string s; print_newline ()

let tree_of_string ?(unhash = make_unhash [])  s : tree =

  let rec read_array s pos =
    let len = Bi_vint.read_uvint s pos in
    if len = 0 then `Array None
    else
      let tag = read_tag s pos in
      let read = reader_of_tag tag in
      `Array (Some (tag, Array.init len (fun _ -> read s pos)))
      
  and read_tuple s pos =
    let len = Bi_vint.read_uvint s pos in
    `Tuple (Array.init len (fun _ -> read_tree s pos))
      
  and read_field s pos =
    let h = read_field_hashtag s pos in
    let name = unhash h in
    let x = read_tree s pos in
    (name, h, x)
      
  and read_record s pos =
    let len = Bi_vint.read_uvint s pos in
    `Record (Array.init len (fun _ -> read_field s pos))
    
  and read_num_variant_cont s pos i has_arg =
    let x =
      if has_arg then
	Some (read_tree s pos)
      else
	None
    in
    `Num_variant (i, x)
  
  and read_num_variant s pos =
    read_numtag s pos read_num_variant_cont
      
  and read_variant_cont s pos h has_arg =
    let name = unhash h in
    let x =
      if has_arg then
	Some (read_tree s pos)
      else
	None
    in
    `Variant (name, h, x)
  
  and read_variant s pos =
    read_hashtag s pos read_variant_cont
      
  and read_record_table s pos =
    let row_num = Bi_vint.read_uvint s pos in
    if row_num = 0 then
      `Record_table None
    else
      let col_num = Bi_vint.read_uvint s pos in
      let fields = 
	Array.init col_num (
	  fun _ ->
	    let h = read_field_hashtag s pos in
	    let name = unhash h in
	    let tag = read_tag s pos in
	    (name, h, tag)
	)
      in
      let readers = 
	Array.map (fun (name, h, tag) -> reader_of_tag tag) fields in
      let a =
	Array.init row_num
	  (fun _ ->
	     Array.init col_num (fun j -> readers.(j) s pos))
      in
      `Record_table (Some (fields, a))
	
  and reader_of_tag = function
      0 (* bool *) -> read_bool
    | 1 (* int8 *) -> read_int8
    | 2 (* int16 *) -> read_int16
    | 3 (* int32 *) -> read_int32
    | 4 (* int64 *) -> read_int64
    | 5 (* int128 *) -> read_int128
    | 12 (* float *) -> read_float
    | 16 (* uvint *) -> read_uvint
    | 17 (* svint *) -> read_svint
    | 18 (* string *) -> read_string
    | 19 (* array *) -> read_array
    | 20 (* tuple *) -> read_tuple
    | 21 (* record *) -> read_record
    | 22 (* num_variant *) -> read_num_variant
    | 23 (* variant *) -> read_variant
    | 25 (* record_table *) -> read_record_table
    | _ -> Bi_util.error "Corrupted data (invalid tag)"
	
  and read_tree s pos : tree =
    reader_of_tag (read_tag s pos) s pos
      
  in
  read_tree s (ref 0)


let skip_bytes n s pos =
  let p = !pos + n in
  pos := p;
  if p > String.length s then
    Bi_util.error "Corrupted data (skip_bytes)"

let skip_bool s pos = skip_bytes 1 s pos
let skip_int8 s pos = skip_bytes 1 s pos
let skip_int16 s pos = skip_bytes 2 s pos
let skip_int32 s pos = skip_bytes 4 s pos
let skip_int64 s pos = skip_bytes 8 s pos
let skip_int128 s pos = skip_bytes 16 s pos
let skip_float s pos = skip_bytes 8 s pos
let skip_uvint s pos = ignore (read_untagged_uvint s pos)
let skip_svint s pos = ignore (read_untagged_svint s pos)

let skip_string s pos =
  let len = Bi_vint.read_uvint s pos in
  skip_bytes len s pos

let rec skip_array s pos =
  let len = Bi_vint.read_uvint s pos in
  if len = 0 then ()
  else
    let tag = read_tag s pos in
    let read = skipper_of_tag tag in
    for i = 1 to len do
      read s pos
    done
      
and skip_tuple s pos =
  let len = Bi_vint.read_uvint s pos in
  for i = 1 to len do
    skip s pos
  done
    
and skip_field s pos =
  ignore (read_field_hashtag s pos);
  skip s pos
    
and skip_record s pos =
  let len = Bi_vint.read_uvint s pos in
  for i = 1 to len do
    skip_field s pos
  done
    
and skip_num_variant_cont s pos i has_arg =
  if has_arg then
    skip s pos
      
and skip_num_variant s pos =
  read_numtag s pos skip_num_variant_cont
    
and skip_variant_cont s pos h has_arg =
  if has_arg then
    skip s pos
      
and skip_variant s pos =
  read_hashtag s pos skip_variant_cont
    
and skip_record_table s pos =
  let row_num = Bi_vint.read_uvint s pos in
  if row_num = 0 then
    ()
  else
    let col_num = Bi_vint.read_uvint s pos in
    let readers = 
      Array.init col_num (
	fun _ ->
	  ignore (read_field_hashtag s pos);
	  skipper_of_tag (read_tag s pos)
      )
    in
    for i = 1 to row_num do
      for j = 1 to col_num do
	readers.(j) s pos
      done
    done
      
and skipper_of_tag = function
    0 (* bool *) -> skip_bool
  | 1 (* int8 *) -> skip_int8
  | 2 (* int16 *) -> skip_int16
  | 3 (* int32 *) -> skip_int32
  | 4 (* int64 *) -> skip_int64
  | 5 (* int128 *) -> skip_int128
  | 12 (* float *) -> skip_float
  | 16 (* uvint *) -> skip_uvint
  | 17 (* svint *) -> skip_svint
  | 18 (* string *) -> skip_string
  | 19 (* array *) -> skip_array
  | 20 (* tuple *) -> skip_tuple
  | 21 (* record *) -> skip_record
  | 22 (* num_variant *) -> skip_num_variant
  | 23 (* variant *) -> skip_variant
  | 25 (* record_table *) -> skip_record_table
  | _ -> Bi_util.error "Corrupted data (invalid tag)"
	
and skip s pos : unit =
  skipper_of_tag (read_tag s pos) s pos
    


module Pp =
struct
  open Easy_format

  let array = list
  let record = list
  let tuple = { list with
		  space_after_opening = false;
		  space_before_closing = false;
		  align_closing = false }
  let variant = { list with
		    separators_stick_left = true }
		    
  let map f a = Array.to_list (Array.map f a)

  let rec format (x : tree) =
    match x with
	`Bool x -> Atom ((if x then "true" else "false"), atom)
      | `Int8 x -> Atom (sprintf "0x%02x" x, atom)
      | `Int16 x -> Atom (sprintf "0x%04x" x, atom)
      | `Int32 x -> Atom (sprintf "0x%08lx" x, atom)
      | `Int64 x -> Atom (sprintf "0x%016Lx" x, atom)
      | `Int128 x -> Atom ("0x" ^ Digest.to_hex x, atom)
      | `Float64 x -> Atom (string_of_float x, atom)
      | `Uvint x -> Atom (string_of_int x, atom)
      | `Svint x -> Atom (string_of_int x, atom)
      | `String s -> Atom (sprintf "%S" s, atom)
      | `Array None -> Atom ("[]", atom)
      | `Array (Some (_, a)) -> List (("[", ",", "]", array), map format a)
      | `Tuple a -> List (("(", ",", ")", tuple), map format a)
      | `Record a -> List (("{", ",", "}", record), map format_field a)
      | `Num_variant (i, o) ->
	  let suffix =
	    if i = 0 then ""
	    else string_of_int i
	  in
	  (match o with
	       None -> Atom ("None" ^ suffix, atom)
	     | Some x ->
		 let cons = Atom ("Some" ^ suffix, atom) in
		 Label ((cons, label), format x))
      | `Variant (opt_name, h, o) ->
	  let name =
	    match opt_name with
		None -> sprintf "#%08lx" (Int32.of_int h)
	      | Some s -> sprintf "<%s>" (String.escaped s)
	  in
	  let cons = Atom (name, atom) in
	  (match o with
	       None -> cons
	     | Some x -> Label ((cons, label), format x))
	  
      | `Record_table None -> Atom ("[]", atom)
      | `Record_table (Some (header, aa)) ->
	  let record_array =
	    `Array (
	      Some (
		record_tag,
		Array.map (
		  fun a ->
		    `Record (
		      Array.mapi (
			fun i x -> 
			  let s, h, _ = header.(i) in
			  (s, h, x)
		      ) a
		    )
		) aa
	      )
	    ) in
	    format record_array
	    
  and format_field (o, h, x) =
    let s =
      match o with
	  None -> sprintf "#%08lx" (Int32.of_int h)
	| Some s -> sprintf "<%s>" (String.escaped s)
    in
    Label ((Atom (sprintf "%s:" s, atom), label), format x)
end


let inspect ?unhash s =
  Easy_format.Pretty.to_string (Pp.format (tree_of_string ?unhash s))
