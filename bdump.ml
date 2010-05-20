(* $Id$ *)

open Printf

(*
let split s = Str.split (Str.regexp ",") s
*)

let split s =
  let acc = ref [] in
  let stop = ref (String.length s) in
  for i = !stop - 1 downto 0 do
    if s.[i] = ',' then (
      let start = i + 1 in
      acc := String.sub s start (!stop - start) :: !acc;
      stop := i
    )
  done;
  String.sub s 0 !stop :: !acc


let load_lines s =
  let ic = open_in s in
  let l = ref [] in
  (try
     while true do
       l := input_line ic :: List.rev !l
     done
   with End_of_file ->
     close_in ic
  );
  !l

let load ic =
  let buf = Buffer.create 1000 in
  try
    while true do
      Buffer.add_string buf (input_line ic);
      Buffer.add_char buf '\n'
    done;
    assert false
  with End_of_file ->
    Buffer.contents buf

let () =
  let dic = ref [] in
  let file = ref None in
  let options = [
    "-w", Arg.String (fun s -> dic := List.rev_append (split s) !dic),
    "word1,word2,...
          Comma-separated list of words to add to the dictionary";

    "-d", Arg.String (fun s -> dic := List.rev_append (load_lines s) !dic),
    "file
          File containing words to add to the dictionary, one per line";
  ] in
  let msg = sprintf "Usage: %s [file] [options]" Sys.argv.(0) in
  let error () =
    Arg.usage options msg in
  let set_file s =
    match !file with
	None -> file := Some s
      | Some _ -> error ()
  in
  Arg.parse options set_file msg;

  let unhash = Bi_io.make_unhash !dic in
  let ic = 
    match !file with
	None -> stdin
      | Some s -> open_in_bin s
  in
  Bi_io.print_view ~unhash (load ic);
  print_newline ();
  close_in ic

