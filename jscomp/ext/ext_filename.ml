(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)








(** Used when produce node compatible paths *)
let node_sep = "/"
let node_parent = ".."
let node_current = "."

type t =
  [ `File of string
  | `Dir of string ]

let cwd = lazy (Sys.getcwd ())

let (//) = Filename.concat

let combine path1 path2 =
  if path1 = "" then
    path2
  else if path2 = "" then path1
  else
  if Filename.is_relative path2 then
    path1// path2
  else
    path2

(* Note that [.//] is the same as [./] *)
let path_as_directory x =
  if x = "" then x
  else
  if Ext_string.ends_with x  Filename.dir_sep then
    x
  else
    x ^ Filename.dir_sep

let absolute_path s =
  let process s =
    let s =
      if Filename.is_relative s then
        Lazy.force cwd // s
      else s in
    (* Now simplify . and .. components *)
    let rec aux s =
      let base,dir  = Filename.basename s, Filename.dirname s  in
      if dir = s then dir
      else if base = Filename.current_dir_name then aux dir
      else if base = Filename.parent_dir_name then Filename.dirname (aux dir)
      else aux dir // base
    in aux s  in
  process s


let chop_extension ?(loc="") name =
  try Filename.chop_extension name
  with Invalid_argument _ ->
    Ext_pervasives.invalid_argf
      "Filename.chop_extension ( %s : %s )"  loc name

let chop_extension_if_any fname =
  try Filename.chop_extension fname with Invalid_argument _ -> fname





let os_path_separator_char = String.unsafe_get Filename.dir_sep 0


(** example
    {[
      "/bb/mbigc/mbig2899/bgit/bucklescript/jscomp/stdlib/external/pervasives.cmj"
        "/bb/mbigc/mbig2899/bgit/bucklescript/jscomp/stdlib/ocaml_array.ml"
    ]}

    The other way
    {[

      "/bb/mbigc/mbig2899/bgit/bucklescript/jscomp/stdlib/ocaml_array.ml"
        "/bb/mbigc/mbig2899/bgit/bucklescript/jscomp/stdlib/external/pervasives.cmj"
    ]}
    {[
      "/bb/mbigc/mbig2899/bgit/bucklescript/jscomp/stdlib//ocaml_array.ml"
    ]}
    {[
      /a/b
      /c/d
    ]}
*)
let relative_path file_or_dir_1 file_or_dir_2 =
  let sep_char = os_path_separator_char in
  let relevant_dir1 =
    (match file_or_dir_1 with
     | `Dir x -> x
     | `File file1 ->  Filename.dirname file1) in
  let relevant_dir2 =
    (match file_or_dir_2 with
     |`Dir x -> x
     |`File file2 -> Filename.dirname file2 ) in
  let dir1 = Ext_string.split relevant_dir1 sep_char   in
  let dir2 = Ext_string.split relevant_dir2 sep_char  in
  let rec go (dir1 : string list) (dir2 : string list) =
    match dir1, dir2 with
    | x::xs , y :: ys when x = y
      -> go xs ys
    | _, _
      ->
      List.map (fun _ -> node_parent) dir2 @ dir1
  in
  match go dir1 dir2 with
  | (x :: _ ) as ys when x = node_parent ->
    String.concat node_sep ys
  | ys ->
    String.concat node_sep  @@ node_current :: ys


(** path2: a/b
    path1: a
    result:  ./b
    TODO: [Filename.concat] with care

    [file1] is currently compilation file
    [file2] is the dependency

    TODO: this is a hackish function: FIXME
*)
let node_relative_path node_modules_shorten (file1 : t)
    (`File file2 as dep_file : [`File of string]) =
  let v = Ext_string.find  file2 ~sub:Literals.node_modules in
  let len = String.length file2 in
  if node_modules_shorten && v >= 0 then

    let rec skip  i =
      if i >= len then
        Ext_pervasives.failwithf ~loc:__LOC__ "invalid path: %s"  file2
      else
        (* https://en.wikipedia.org/wiki/Path_(computing))
           most path separator are a single char
        *)
        let curr_char = String.unsafe_get file2 i  in
        if curr_char = os_path_separator_char || curr_char = '.' then
          skip (i + 1)
        else i
        (*
          TODO: we need do more than this suppose user
          input can be
           {[
             "xxxghsoghos/ghsoghso/node_modules/../buckle-stdlib/list.js"
           ]}
           This seems weird though
        *)
    in
    Ext_string.tail_from file2
      (skip (v + Literals.node_modules_length))
  else
    relative_path
      (  match dep_file with
         | `File x -> `File (absolute_path x)
         | `Dir x -> `Dir (absolute_path x))

      (match file1 with
       | `File x -> `File (absolute_path x)
       | `Dir x -> `Dir(absolute_path x))
    ^ node_sep ^
    (* chop_extension_if_any *) (Filename.basename file2)



(* Input must be absolute directory *)
let rec find_root_filename ~cwd filename   =
  if Sys.file_exists (cwd // filename) then cwd
  else
    let cwd' = Filename.dirname cwd in
    if String.length cwd' < String.length cwd then
      find_root_filename ~cwd:cwd'  filename
    else
      Ext_pervasives.failwithf
        ~loc:__LOC__
        "%s not found from %s" filename cwd


let find_package_json_dir cwd  =
  find_root_filename ~cwd  Literals.bsconfig_json

let package_dir = lazy (find_package_json_dir (Lazy.force cwd))



let module_name_of_file file =
  String.capitalize
    (Filename.chop_extension @@ Filename.basename file)

let module_name_of_file_if_any file =
  String.capitalize
    (chop_extension_if_any @@ Filename.basename file)


(** For win32 or case insensitve OS
    [".cmj"] is the same as [".CMJ"]
*)
(* let has_exact_suffix_then_chop fname suf =  *)

let combine p1 p2 =
  if p1 = "" || p1 = Filename.current_dir_name then p2 else
  if p2 = "" || p2 = Filename.current_dir_name then p1
  else
  if Filename.is_relative p2 then
    Filename.concat p1 p2
  else p2



(**
   {[
     split_aux "//ghosg//ghsogh/";;
     - : string * string list = ("/", ["ghosg"; "ghsogh"])
   ]}
   Note that
   {[
     Filename.dirname "/a/" = "/"
       Filename.dirname "/a/b/" = Filename.dirname "/a/b" = "/a"
   ]}
   Special case:
   {[
     basename "//" = "/"
       basename "///"  = "/"
   ]}
   {[
     basename "" =  "."
       basename "" = "."
       dirname "" = "."
       dirname "" =  "."
   ]}
*)
let split_aux p =
  let rec go p acc =
    let dir = Filename.dirname p in
    if dir = p then dir, acc
    else
      let new_path = Filename.basename p in
      if Ext_string.equal new_path Filename.dir_sep then
        go dir acc
        (* We could do more path simplification here
           leave to [rel_normalized_absolute_path]
        *)
      else
        go dir (new_path :: acc)

  in go p []



(**
   TODO: optimization
   if [from] and [to] resolve to the same path, a zero-length string is returned
*)
let rel_normalized_absolute_path from to_ =
  let root1, paths1 = split_aux from in
  let root2, paths2 = split_aux to_ in
  if root1 <> root2 then root2
  else
    let rec go xss yss =
      match xss, yss with
      | x::xs, y::ys ->
        if Ext_string.equal x  y then go xs ys
        else
          let start =
            List.fold_left (fun acc _ -> acc // Ext_string.parent_dir_lit )
              Ext_string.parent_dir_lit  xs in
          List.fold_left (fun acc v -> acc // v) start yss
      | [], [] -> Ext_string.empty
      | [], y::ys -> List.fold_left (fun acc x -> acc // x) y ys
      | x::xs, [] ->
        List.fold_left (fun acc _ -> acc // Ext_string.parent_dir_lit )
          Ext_string.parent_dir_lit xs in
    go paths1 paths2

(**
  Instead of splitting a string, returns a list of indices where directory names start
 *)
let split_aux_idx x =
  let l = String.length x in
  let ds = Filename.dir_sep.[0] in (*dir_sep as char*)
  let rec ctr i =
    if i = l || x.[i] = ds then i - 1
    else ctr (i+1)
  in
  let rec h accum sidx =
    if sidx = l then accum
    else
      if x.[sidx] = ds then h accum (sidx+1)
      else
        let eidx = ctr (sidx+1) in
        h (accum@[(sidx, eidx)]) (eidx+1)
  in
  h [] 0

(* TODO: could be highly optimized later
  {[
    normalize_absolute_path "/gsho/./..";;

    normalize_absolute_path "/a/b/../c../d/e/f";;

    normalize_absolute_path "/gsho/./..";;

    normalize_absolute_path "/gsho/./../..";;

    normalize_absolute_path "/a/b/c/d";;

    normalize_absolute_path "/a/b/c/d/";;

    normalize_absolute_path "/a/";;

    normalize_absolute_path "/a";;

    normalize_absolute_path "C:/gsho/./..";;

    normalize_absolute_path "d:/a/b/../c../d/e/f";;

    normalize_absolute_path "e:/gsho/./..";;

    normalize_absolute_path "b:/gsho/./../..";;

    normalize_absolute_path "a:/a/b/c/d";;

    normalize_absolute_path "f:/a/b/c/d/";;

    normalize_absolute_path "g:/a/";;

    normalize_absolute_path "h:/a";;
  ]}
*)
(** See tests in {!Ounit_path_tests} *)
let normalize_absolute_path x =
  let d = '.' in
  let ds = Filename.dir_sep.[0] in
  let root, rem =
    let fst_sep = (String.index x ds) in
    String.sub x 0 (fst_sep),
    String.sub x (fst_sep+1) (String.length x - (fst_sep+1))
  in
  let len (st, ed) = ed - st + 1 in
  let idxs =
    split_aux_idx rem
    |> List.rev
    |> List.fold_left
      (fun (acc,skip) elm ->
        if len elm = 1 && rem.[fst elm] = d then acc,skip
        else if len elm = 2 && rem.[fst elm] = d && rem.[snd elm] = d then
          acc,skip+1
        else if skip <> 0 then acc,skip-1
        else (elm::acc),0
      )
      ([], 0)
    |> fst
  in
  let ans =
    Bytes.create ((1 + String.length root) +
                  (List.map len idxs |> List.fold_left (+) 0) +
                  (List.length idxs) - 1)
  in
  Bytes.blit_string root 0 ans 0 (String.length root);
  let ans' =
    List.fold_left
      (fun (acc,curidx) elm ->
        Bytes.blit_string Filename.dir_sep 0 acc curidx 1;
        Bytes.blit_string rem (fst elm) acc (curidx+1) (len elm);
        acc,curidx+(len elm)+1
      )
      (ans,String.length root)
      idxs
  in
  ans' |> fst |> Bytes.unsafe_to_string

let get_extension x =
  let pos = Ext_string.rindex_neg x '.' in
  if pos < 0 then ""
  else Ext_string.tail_from x pos


let simple_convert_node_path_to_os_path =
  if Sys.unix then fun x -> x
  else if Sys.win32 || Sys.cygwin then
    Ext_string.replace_slash_backward
  else failwith ("Unknown OS : " ^ Sys.os_type)


let output_js_basename s =
  String.uncapitalize s ^ Literals.suffix_js