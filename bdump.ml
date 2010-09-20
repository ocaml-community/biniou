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


let load_lines accu s =
  let ic = open_in s in
  let l = ref accu in
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

let ( // ) = Filename.concat

let global_dict_path =
  try
    match Sys.os_type with
        "Unix" -> Some (Sys.getenv "HOME" // ".bdump-dict")
      | "Win32" -> Some (Sys.getenv "HOMEPATH" // "_bdump-dict")
      | "Cygwin" -> Some (Sys.getenv "HOME" // ".bdump-dict")
      | _ -> None
  with Not_found ->
    None

let load_global_dictionary accu =
  match global_dict_path with
      None -> accu
    | Some fn ->
        if Sys.file_exists fn then
          try
            load_lines accu fn
          with e ->
            failwith (sprintf "Cannot load global dictionary from %S: %s\n%!"
                        fn (Printexc.to_string e))
        else
          accu

let write_uniq oc a =
  if Array.length a > 0 then (
    fprintf oc "%s\n" a.(0);
    ignore (
      Array.fold_left (
        fun last x ->
          if last <> x then
            fprintf oc "%s\n" x;
          x
      ) a.(0) a
    )
  )

let save_global_dictionary l =
  match global_dict_path with
      None -> ()
    | Some fn ->
        let a = Array.of_list l in
        Array.sort String.compare a;
        let oc = open_out fn in
        let finally () = close_out_noerr oc in
        try
          write_uniq oc a;
          finally ()
        with e ->
          finally ();
          raise e
    
let () =
  let dic = ref [] in
  let file = ref None in
  let use_global_dictionary = ref true in
  let options = [
    "-d", Arg.String (fun s -> dic := load_lines !dic s),
    "file
          File containing words to add to the dictionary, one per line";

    "-w", Arg.String (fun s -> dic := List.rev_append (split s) !dic),
    "word1,word2,...
          Comma-separated list of words to add to the dictionary";

    "-x", Arg.Clear use_global_dictionary,
    sprintf "
          Do not load nor update the global dictionary used for name
          unhashing%s."
      (match global_dict_path with
           None -> ""
         | Some s -> sprintf " (file %S)" s);
  ]
  in
  let msg = sprintf "Usage: %s [file] [options]" Sys.argv.(0) in
  let error () =
    Arg.usage options msg in
  let set_file s =
    match !file with
	None -> file := Some s
      | Some _ -> error ()
  in
  Arg.parse options set_file msg;

  if !use_global_dictionary then (
    let must_save = !dic <> [] in
    dic := load_global_dictionary !dic;
    if must_save then
      save_global_dictionary !dic
  );

  let unhash = Bi_io.make_unhash !dic in
  let ic = 
    match !file with
	None -> stdin
      | Some s -> open_in_bin s
  in
  Bi_io.print_view ~unhash (load ic);
  print_newline ();
  close_in ic

