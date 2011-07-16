open Printf

let error s = failwith s

let input_int64 ic =
  let n = ref 0 in
  for i = 1 to 8 do
    n := (!n lsl 8) lor (input_byte ic);
    if !n < 0 then
      error "Corrupted stream: excessive chunk length"
  done;
  !n

let output_int64 oc n =
  let n = ref n in
  for i = 1 to 8 do
    output_char oc (char_of_int (!n lsr 56));
    n := !n lsl 8
  done

let rec read_chunk of_string ic =
  match input_char ic with
      '\001' ->
        let len = input_int64 ic in
        if len > Sys.max_string_length then
          error
            (sprintf 
               "Corrupted stream: excessive chunk length (%i bytes)" len);
        let s = String.create len in
        really_input ic s 0 len;
        Some (of_string s)
        
    | '\000' -> None

    | c -> error (sprintf "Corrupted stream: %C" c)


let flatten st =
  let a = ref [| |] in
  let pos = ref 0 in
  let rec next i =
    if !pos >= Array.length !a then (
      match Stream.peek st with
          None -> None
        | Some a' ->
            Stream.junk st;
            a := a';
            pos := 0;
            next i
    )
    else (
      let x = (!a).(!pos) in
      incr pos;
      Some x
    )
  in
  Stream.from next


let read_stream of_string ic =
  flatten (Stream.from (fun i -> read_chunk of_string ic))

let rev_array_of_list l =
  match l with
      [] -> [||]
    | x :: tl ->
        let r = ref tl in
        let len = List.length l in
        let a = Array.make len x in
        for i = len - 2 downto 0 do
          match !r with
              hd :: tl ->
                a.(i) <- hd;
                r := tl;
            | [] -> assert false
        done;
        a

let write_stream ?(chunk_len = 1024) to_string oc st =
  let n = ref 0 in
  let acc = ref [] in
  let flush_chunk () =
    let a = rev_array_of_list !acc in
    acc := [];
    n := 0;
    let s = to_string a in
    output_char oc '\001';
    output_int64 oc (String.length s);
    output_string oc s
  in
  Stream.iter (
    fun x ->
      incr n;
      acc := x :: !acc;
      if !n >= chunk_len then
        flush_chunk ()
  ) st;
  if !n > 0 then
    flush_chunk ();
  output_char oc '\000'


let test l =
  List.iter (fun x -> assert (x >= 0 && x <= 9)) l;
  let to_string a =
    String.concat "" (List.map string_of_int (Array.to_list a))
  in
  let of_string s =
    Array.init (String.length s) (fun i -> int_of_string (String.make 1 s.[i]))
  in
  let st = Stream.of_list l in
  let oc = open_out "test-stream.dat" in
  write_stream ~chunk_len:2 to_string oc st;
  close_out oc;

  let ic = open_in "test-stream.dat" in
  let st' = read_stream of_string ic in
  let l' = ref [] in
  Stream.iter (fun i -> l' := i :: !l') st';
  close_in ic;
  l = List.rev !l'
