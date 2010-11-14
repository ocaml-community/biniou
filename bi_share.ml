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
  let clear tbl =
    if H.length tbl > 0 then
      H.clear tbl

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
  let clear tbl =
    if Hashtbl.length tbl > 0 then
      Hashtbl.clear tbl

  let put tbl pos x =
    Hashtbl.add tbl pos x

  let get tbl pos =
    try Hashtbl.find tbl pos
    with Not_found ->
      Bi_util.error "Corrupted data (invalid reference)"
end

module Rd_poly =
struct
  type type_id = int
  type tbl = ((int * type_id), Obj.t) Hashtbl.t

  let dummy_type_id = 0

  let create_type_id =
    let n = ref dummy_type_id in
    fun () ->
      incr n;
      if !n < 0 then
        failwith "Bi_share.Rd_poly.create_type_id: \
                  exhausted available type_id's"
      else
        !n

  let create = Hashtbl.create
  let clear = Hashtbl.clear

  let put tbl pos x =
    Hashtbl.add tbl pos x

  let get tbl pos =
    try Hashtbl.find tbl pos
    with Not_found ->
      Bi_util.error "Corrupted data (invalid reference)"
end
