(* $Id$ *)

let () =
  let buf = Buffer.create 1000 in
  try
    while true do
      Buffer.add_string buf (input_line stdin);
      Buffer.add_char buf '\n'
    done
  with End_of_file ->
    print_endline (Bi_io.inspect (Buffer.contents buf))

