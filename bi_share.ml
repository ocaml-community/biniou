(* $Id$ *)

module Wr =
struct
  module H = Hashtbl.Make (
    struct
      type t = Obj.t
      let equal = ( == )
      let hash = Hashtbl.hash
    end
  )

  type tbl = int H.t
      
  let create = H.create
  let clear = H.clear

  let put tbl x pos =
    try
      let pos0 = H.find tbl (Obj.repr x) in
      pos - pos0
    with Not_found ->
      H.add tbl (Obj.repr x) pos;
      0
end

module Rd =
struct
  type 'a tbl = (int, 'a) Hashtbl.t

  let create = Hashtbl.create
  let clear = Hashtbl.clear

  let put tbl pos x =
    Hashtbl.add tbl pos x

  let get tbl pos =
    try Hashtbl.find tbl pos
    with Not_found ->
      Bi_util.error "Corrupted data (invalid reference)"
end
