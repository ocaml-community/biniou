(* $Id$ *)

open Bi_io

let test_tree : tree =
  `Tuple [|
    `Num_variant (0, None);
    `Num_variant (0, Some (`Svint 127));
    `Array (Some (svint_tag, [| `Svint 1; `Svint 2 |]));
    `Record [|
      (Some "abc", hash_name "abc", `String "hello");
      (Some "number", hash_name "number", `Svint 123);
      (Some "variant1", hash_name "variant1", 
       `Variant (Some "Foo", hash_name "Foo", Some (`Svint (-456))));
      (Some "variant2", hash_name "variant2", 
       `Variant (Some "Bar", hash_name "Bar", None));
    |];
    `Record_table (
      Some (
	[| (Some "name", hash_name "name", string_tag);
	   (Some "age", hash_name "age", uvint_tag) |],
	[|
	  [| `String "Francisco"; `Uvint 67 |];
	  [| `String "Mateo"; `Uvint 23 |];
	  [| `String "Clara"; `Uvint 27 |];
	  [| `String "Jose"; `Uvint 39 |];
	|]
      )
    )
|]

let unhash = make_unhash [ "abc"; "number";
			   "variant1"; "variant2";
			   "Foo"; "Bar";
			   "name"; "age" ]

let test () =
  let s = string_of_tree test_tree in
  let test_tree2 = tree_of_string ~unhash s in
  (s, String.length s, test_tree2, test_tree2 = test_tree)


let test_json () =
  let s =
    "[\
       null,\
       127,\
       [1,2],\
       {\"abc\":\"hello\",\
       \"number\":123,\
       \"variant1\":[\"Foo\",-456],\
       \"variant2\":\"Bar\"},\
       [[1,\"first\"],[2,\"second\"],[3,\"third\"],[4,\"fourth\"]],\
       [\
         {\"name\":\"Francisco\",\"age\":67},\
         {\"name\":\"Mateo\",\"age\":23},\
         {\"name\":\"Clara\",\"age\":27},\
         {\"name\":\"Jose\",\"age\":39}\
       ],\
       [\
        [1.234567,2.345678,3.456789],\
        [4.567890,5.678901,6.789012],\
        [7.890123,8.901234,9.012345],\
        [10.123456,11.234567,12.345678]\
       ],\
     ]" in
  s, String.length s

type foo = {
  abc : string;
  number : int;
  variant1 : [ `Foo of int ];
  variant2 : [ `Bar ]
}

type person = {
  name : string;
  age : int
}

let native_test_tree =
  (
    None,
    Some 127,
    [| 1; 2 |],
    { abc = "hello";
      number = 123;
      variant1 = `Foo (-456);
      variant2 = `Bar },
    [|
      1, "first";
      2, "second";
      3, "third";
      4, "fourth";
    |],
    [|
      { name = "Francisco"; age = 67 };
      { name = "Mateo"; age = 23 };
      { name = "Clara"; age = 27 };
      { name = "Jose"; age = 39 };
    |],
    [|
      [| 1.234567; 2.345678; 3.456789 |]; 
      [| 4.567890; 5.678901; 6.789012 |]; 
      [| 7.890123; 8.901234; 9.012345 |]; 
      [| 10.123456; 11.234567; 12.345678 |]
    |]
  )

let test_marshal () =
  let s = Marshal.to_string native_test_tree [] in
  s, String.length s

let marshal_wr_perf n =
  for i = 1 to n do
    ignore (Marshal.to_string native_test_tree [Marshal.No_sharing])
  done

let biniou_wr_perf n =
  for i = 1 to n do
    ignore (string_of_tree test_tree)
  done

let time name f x =
  let t1 = Unix.gettimeofday () in
  ignore (f x);
  let t2 = Unix.gettimeofday () in
  Printf.printf "%s: %.3f\n%!" name (t2 -. t1)

let wr_perf () =
  let n = 1_000_000 in
  time "biniou" biniou_wr_perf n;
  time "marshal" marshal_wr_perf n


let _ =
  let s = string_of_tree test_tree in
  print_string (Bi_io.inspect s);
  print_newline ();

  let oc = open_out_bin "test.bin" in
  output_string oc s;
  close_out oc;

  wr_perf ()
