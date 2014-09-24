(* New monomorphisation routine *)
open Flx_util
open Flx_btype
open Map
open Flx_mtypes2
open Flx_print
open Flx_types
open Flx_bbdcl
open Flx_bexpr
open Flx_bexe
open Flx_bparameter
module CS = Flx_code_spec

let show bsym_table i = 
  Flx_bsym_table.find_id bsym_table i ^ "<" ^ si i ^ ">"

let showts bsym_table i ts =
  show bsym_table i ^ "[" ^ catmap "," (sbt bsym_table) ts ^ "]"

let showvars bsym_table vars = 
  catmap "," (fun (i,t)-> si i ^ " |-> " ^ sbt bsym_table t) vars

(* ----------------------------------------------------------- *)
(* ROUTINES FOR REPLACING TYPE VARIABLES IN TYPES              *)
(* ----------------------------------------------------------- *)

let check_mono bsym_table t =
  if BidSet.empty <> Flx_unify.vars_in t then begin
    print_endline (" **** Failed to monomorphise type " ^ sbt bsym_table t);
    print_endline (" **** got type " ^ sbt bsym_table t);
    assert false
  end

let check_mono_vars bsym_table vars t =
  try check_mono bsym_table t
  with _ -> 
    print_endline (" **** using varmap " ^ showvars bsym_table vars);
    assert false

let mono_type syms bsym_table vars t = 
  let t = Flx_unify.list_subst syms.counter vars t in
  begin try check_mono bsym_table t with _ -> assert false end;
  t

let rec mono_expr syms bsym_table vars e =
  let f_btype t = mono_type syms bsym_table vars t in
  let f_bexpr e = mono_expr syms bsym_table vars e in
  Flx_bexpr.map ~f_btype ~f_bexpr e

let rec mono_exe syms bsym_table vars exe =
  let f_btype t = mono_type syms bsym_table vars t in
  let f_bexpr e = mono_expr syms bsym_table vars e in
  Flx_bexe.map ~f_btype ~f_bexpr exe

(* ----------------------------------------------------------- *)

let rec fixup_type' syms bsym_table fi t =
(*
  print_endline ("FIXUP TYPE' " ^ sbt bsym_table t);
*)
  match t with
  | BTYP_inst (i,ts) ->
(*
    let sym = 
      try Flx_bsym_table.find bsym_table i 
      with Not_found -> 
       print_endline ("[fixup_type'] Cannot find symbol " ^ si i);
       assert false
    in
    let {Flx_bsym.id=id;sr=sr;vs=vs;bbdcl=bbdcl} = sym in
    begin match bbdcl with
    | BBDCL_newtype (vs,t) ->
      print_endline "Adjust newtype?";
      assert (List.length vs = List.length ts);
      let vars = List.map2 (fun (s,i) t -> i,t) vs ts in
      let concrete_type = Flx_unify.list_subst syms.counter vars t in
      fixup_type syms bsym_table fi concrete_type

    | _ ->
      (* typeclass fixup *)
*)
      let i',ts' = fi i ts in
      if i <> i || ts <> ts' then
        print_endline ("FIXUP TYPE INSTANCE " ^ showts bsym_table i ts ^ " => " ^ 
        si i'^ "{"^catmap "," (sbt bsym_table) ts'^"}");
      let t = btyp_inst (i',ts') in
      t
(*
    end
*)

  | x -> x

and fixup_type syms bsym_table fi t =
(*
  print_endline ("  <++ FIXUP TYPE " ^ sbt bsym_table t);
*)
  let f_btype t = fixup_type' syms bsym_table fi t in
  let t = Flx_btype.map ~f_btype t in
(*
  print_endline ("  ++> FIXEDUP TYPE " ^ sbt bsym_table t);
*)
  t

let applysubst syms bsym_table fi (e,t) =
(*
  print_endline ("FIXUP EXPR(up) " ^ sbe bsym_table (e, btyp_void ()));
*)
  let x = match e with
  | BEXPR_apply_prim (i',ts,a) -> assert false
(*
    let i,ts = fi i' ts in
    (* CRAP to account for virtuals *)
    if i = i' then
      bexpr_apply_prim t (i,ts,a)
    else
      bexpr_apply_direct t (i,ts,a)
*)

  | BEXPR_apply_direct (i,ts,a) -> assert false
(*
    let i,ts = fi i ts in
    bexpr_apply_direct t (i,ts,a)
*)

  | BEXPR_apply_struct (i,ts,a) -> assert false
(*
    let i,ts = fi i ts in
    bexpr_apply_struct t (i,ts,a)
*)

  | BEXPR_apply_stack (i,ts,a) -> assert false
(*
    let i,ts = fi i ts in
    bexpr_apply_stack t (i,ts,a)
*)
  | BEXPR_ref (i,ts)  ->
    let i,ts = fi i ts in
    bexpr_ref t (i,ts)

  | BEXPR_name (i',ts') ->
    let i,ts = fi i' ts' in
    (*
    print_endline (
      "Ref to Variable " ^ si i' ^ "[" ^ catmap "," (sbt bsym_table) ts' ^"]" ^
      " mapped to " ^ si i ^ "[" ^ catmap "," (sbt bsym_table) ts ^"]"
    );
    *)
    bexpr_name t (i,ts)

  | BEXPR_closure (i,ts) ->
    let i,ts = fi i ts in
    bexpr_closure t (i,ts)

  | x -> x, t
  in
  (*
  print_endline ("FIXed UP EXPR " ^ sbe sym_table (x, btyp_void ()));
  *)
  x

(* mt is only used to fixup svc and init hacks *)
let fixup_exe syms bsym_table fi mt exe =
(*
  print_endline ("FIXUP EXE[In] =" ^ string_of_bexe bsym_table 0 exe);
*)
  let result =
  match exe with
  | BEXE_call_direct (sr, i,ts,a) -> assert false
    (*
    let i,ts = fi i ts in
    bexe_call_direct (sr,i,ts,a)
    *)

  | BEXE_jump_direct (sr, i,ts,a) -> assert false
    (*
    let i,ts = fi i ts in
    bexe_jump_direct (sr,i,ts,a)
    *)

  | BEXE_call_prim (sr, i',ts,a) -> assert false
    (*
    let i,ts = fi i' ts in
    if i = i' then
      bexe_call_prim (sr,i,ts,a)
    else
      bexe_call_direct (sr,i,ts,a)
    *)

  | BEXE_call_stack (sr, i,ts,a) -> assert false
    (*
    let i,ts = fi i ts in
    bexe_call_stack (sr,i,ts,a)
    *)

  (* this is deviant case: implied ts is vs of parent! *)
  | BEXE_init (sr,i,e) ->
    print_endline ("[init] Deviant case variable " ^ si i);
    let vs = 
      try Flx_bsym_table.find_bvs bsym_table i 
      with Not_found -> assert false
    in
    let ts = List.map (fun (s,j) -> mt (btyp_type_var (j, btyp_type 0))) vs in
    let i,ts = fi i ts in
    (*
    print_endline ("[init] Remapped deviant variable to " ^ si i);
    *)
    bexe_init (sr,i,e)

  | BEXE_svc (sr,i) ->
    print_endline ("[svc] Deviant case variable " ^ si i);
    let vs = 
      try Flx_bsym_table.find_bvs bsym_table i 
      with Not_found -> assert false
    in
    let ts = List.map (fun (s,j) -> mt (btyp_type_var (j, btyp_type 0))) vs in
    let i,ts = fi i ts in
    (*
    print_endline ("[svc] Remapped deviant variable to " ^ si i);
    *)
    bexe_svc (sr,i)

  | x -> x
  in
  (*
  print_endline ("FIXUP EXE[Out]=" ^ string_of_bexe sym_table 0 result);
  *)
  result

let fixup_expr syms bsym_table monotype virtualinst fi e =
  print_endline ("[fixup_expr] " ^ sbe bsym_table e);
  (* monomorphise the code by eliminating type variables *)
  let e = Flx_bexpr.map ~f_btype:monotype e in

  (* eliminate virtual calls by mapping to instances *)
  let e = Flx_bexpr.map ~f_bexpr:(applysubst syms bsym_table virtualinst) e in

  (* replace applications of polymorphic function (or variable)
    with applications of new monomorphic ones
  *)
  let e = Flx_bexpr.map ~f_bexpr:(applysubst syms bsym_table fi) e in
  e

let show_exe bsym_table exe = string_of_bexe bsym_table 4 exe
let show_exes bsym_table exes = catmap "\n" (show_exe bsym_table) exes


(* rewrite to do in one pass *)
let fixup_exes syms bsym_table vars virtualinst fi exes =
  (* monomorphise the code by eliminating type variables *)
(*
  print_endline ("To fixup exes:\n" ^ show_exes bsym_table exes);
*)
  let exes = List.map (mono_exe syms bsym_table vars) exes in
(*
  print_endline ("Monomorphised:\n" ^ show_exes bsym_table exes);
  print_endline ("VARS=" ^ showvars bsym_table vars);
*)
  (* eliminate virtual calls by mapping to instances *)
  let exes = List.map (fun exe -> Flx_bexe.map ~f_bexpr:(applysubst syms bsym_table virtualinst) exe) exes in
(*
  print_endline ("Virtuals Instantiated:\n" ^ show_exes bsym_table exes);
*)
  (* replace applications of polymorphic function (or variable)
    with applications of new monomorphic ones
  *)
  let exes = List.map (fun exe -> Flx_bexe.map ~f_bexpr:(applysubst syms bsym_table fi) exe) exes in
(*
  print_endline ("Applies monomorphised:\n" ^ show_exes bsym_table exes);
*)
  (* replace weird cases in exes with implied ts *)
  let exes = List.map (fixup_exe syms bsym_table fi (mono_type syms bsym_table vars))  exes in
(*
  print_endline ("Special calls monomorphised:\n" ^ show_exes bsym_table exes);
*)
  exes

type symkind = Felix of int | External

module MonoMap = Map.Make (
  struct 
    type t = int * Flx_btype.t list 
    let compare = compare 
  end
)

let find_inst syms processed to_process i ts =
  try 
    Some (MonoMap.find (i,ts) !processed)
  with Not_found ->
  try
    Some (MonoMap.find (i,ts) !to_process)
  with Not_found -> None

let find_felix_inst syms bsym_table processed to_process i ts : int =
  match find_inst syms processed to_process i ts with
  | None ->
    let k = 
      if List.length ts = 0 then i else fresh_bid syms.counter 
    in
    let target = Felix k in
    to_process := MonoMap.add (i,ts) target !to_process;
    print_endline ("Add Felix inst to process: " ^ showts bsym_table i ts ^ " --> "^si k);
    k
  | Some (Felix k) -> k
  | Some External -> assert false

let find_external_inst syms bsym_table processed to_process i ts : int =
  match find_inst syms processed to_process i ts with
  | None ->
    let target = External in
    to_process := MonoMap.add (i,ts) target !to_process;
    i
  | Some (External) -> i
  | Some (Felix _) -> assert false
 
let mt syms bsym_table vars bsym fi t =
(*
  print_endline ("    ** mt " ^ sbt bsym_table t);
*)
  let nut1 = mono_type syms bsym_table vars t in
(*
  print_endline ("    ** fixup_type " ^ sbt bsym_table nut1);
*)
  let nut2 = fixup_type syms bsym_table fi nut1 in
(*
  print_endline ("    ** Betareduce " ^ sbt bsym_table nut2);
*)
  let rt = Flx_beta.beta_reduce "flx_mono: mono, metatype"
    syms.Flx_mtypes2.counter
    bsym_table
    (Flx_bsym.sr bsym)
    nut2
  in 
(*
  print_endline ("    ** Betareduced " ^ sbt bsym_table rt);
*)
  rt

let mono syms bsym_table virtualinst fi ts bsym =
(*
  print_endline ("[mono] " ^ Flx_bsym.id bsym);
*)
  begin try List.iter (check_mono bsym_table) ts with _ -> assert false end;

  let mt vars t = mt syms bsym_table vars bsym fi t in
  match Flx_bsym.bbdcl bsym with
  | BBDCL_fun (props,vs,(ps,traint),ret,exes) ->
    begin try
      let props = List.filter (fun p -> p <> `Virtual) props in
      if List.length vs <> List.length ts then begin
        print_endline ("[mono] vs/ts mismatch in " ^ Flx_bsym.id bsym ^ " vs=[" ^ 
          catmap "," (fun (s,i) -> s) vs ^ "], ts=[" ^ 
          catmap "," (sbt bsym_table) ts ^ "]");
        assert false;
      end;
      let vars = List.map2 (fun (s,i) t -> i,t) vs ts in
      let ret = mt vars ret in
      let ps = List.map (fun {pkind=pk; pid=s;pindex=i; ptyp=t} ->
        {pkind=pk;pid=s;pindex=fst (fi i ts);ptyp=mt vars t}) ps
      in
      let traint =
        match traint with
        | None -> None
        | Some x -> Some (fixup_expr syms bsym_table (mt vars) virtualinst fi x)
      in
      let exes = 
        try fixup_exes syms bsym_table vars virtualinst fi exes 
        with Not_found -> assert false
      in
      Some (bbdcl_fun (props,[],(ps,traint),ret,exes))
    with Not_found ->
      assert false
    end

  | BBDCL_val (vs,t,kind) ->
    assert (List.length vs = List.length ts);
    let vars = List.map2 (fun (s,i) t -> i,t) vs ts in
    let t = mt vars t in
    Some (bbdcl_val ([],t,kind))

  (* we have tp replace types in interfaces like Vector[int]
    with monomorphic versions if any .. even if we don't
    monomorphise the bbdcl itself.

    This is weak .. it's redone for each instance, relies
    on mt being idempotent..
  *)
  | BBDCL_external_fun (props,vs,argtypes,ret,ct,reqs,prec) ->
    assert (List.length vs = List.length ts);
    let vars = List.map2 (fun (s,i) t -> i,t) vs ts in
    let argtypes = List.map (mt vars) argtypes in
    let ret = mt vars ret in
    Some (bbdcl_external_fun (props,vs,argtypes,ret,ct,reqs,prec))

  | BBDCL_external_const (props, vs, t, CS.Str "#this", reqs) ->
    assert (List.length vs = List.length ts);
    let vars = List.map2 (fun (s,i) t -> i,t) vs ts in
    let t = mt vars t in
    Some (bbdcl_external_const (props, [], t, CS.Str "#this", reqs))

  | BBDCL_external_const _
  | BBDCL_external_type _ 
  | BBDCL_external_code _   -> assert false

  | BBDCL_union _
  | BBDCL_cstruct _
  | BBDCL_struct _  -> print_endline "Mono union,struct,cstruct temp ignored"; None (* ?? *)

  | BBDCL_const_ctor _ 
  | BBDCL_nonconst_ctor _ -> assert false

  | BBDCL_typeclass _ -> assert false
  | BBDCL_instance _ -> assert false

  | BBDCL_axiom 
  | BBDCL_lemma 
  | BBDCL_reduce -> assert false 

  | BBDCL_invalid 
  | BBDCL_newtype _ ->  assert false
  
  | BBDCL_module -> assert false


let rec mono_element debug syms to_process processed bsym_table nutab i ts j =
  let virtualinst i ts =
    try Flx_typeclass.maybe_fixup_typeclass_instance syms bsym_table i ts 
    with Not_found -> assert false
  in

  let fi i ts =  
    let sym = 
      try Flx_bsym_table.find bsym_table i 
      with Not_found -> assert false
     in
    let {Flx_bsym.id=id;sr=sr; bbdcl=bbdcl} = sym in
    match bbdcl with
    | BBDCL_external_type _ 
    | BBDCL_external_const _ 
    | BBDCL_external_fun _ 
    | BBDCL_external_code _  -> 
      let _ = find_external_inst syms bsym_table processed to_process i ts in
      i,ts
    | _ ->
      let j = find_felix_inst syms bsym_table processed to_process i ts in
      j,[]
  in
  print_endline ("numono: "^showts bsym_table i ts ^" ==> " ^ si j);
  begin try List.iter (check_mono bsym_table) ts with _ -> assert false end;
  try
    let parent,sym = 
      try Flx_bsym_table.find_with_parent bsym_table i 
      with Not_found -> assert false
    in
    let {Flx_bsym.id=id;sr=sr;bbdcl=bbdcl} = sym in
    let parent = match parent with
      | None -> None
      | Some 0 -> Some 0 
      | Some p -> 
        let psym = 
          try Flx_bsym_table.find bsym_table p 
          with Not_found -> 
            print_endline ("[mono_element] Cannot find parent " ^ si p);
            assert false 
        in
        let {Flx_bsym.id=id;sr=sr;bbdcl=bbdcl} = psym in
        begin match bbdcl with
        | BBDCL_fun (_,vs,_,_,_) ->
          if debug then print_endline ("  parent is " ^ si p ^" = " ^ id);
          let n = List.length vs in
          let pts = Flx_list.list_prefix ts n in 
(*
print_endline ("Our ts = " ^ catmap "," (sbt bsym_table) ts);
print_endline ("Parent vs = " ^ catmap "," (fun (s,i) -> s) vs);
print_endline ("Parent ts = " ^ catmap "," (sbt bsym_table) pts);
*)
          Some (find_felix_inst syms bsym_table processed to_process p pts)

        | BBDCL_instance _
        | BBDCL_module
        | BBDCL_typeclass _ -> None
        | _ -> assert false 
        end
    in
    let maybebbdcl = 
      try mono syms bsym_table virtualinst fi ts sym 
      with Not_found -> assert false 
    in
    begin match maybebbdcl with
    | Some nubbdcl -> 
      let nusym ={Flx_bsym.id=id; sr=sr; bbdcl=nubbdcl} in
      Flx_bsym_table.add nutab j parent nusym
    | None -> ()
    end
  with Not_found -> 
   print_endline "NOT FOUND in mono_element";
   raise Not_found

let monomorphise2 debug syms bsym_table =
  let roots: BidSet.t = !(syms.roots) in
  assert (BidSet.cardinal roots > 0);


  (* to_process is the set of symbols yet to be scanned
     searching for symbols to monomorphise
  *)
  let to_process = ref MonoMap.empty in
  BidSet.iter (fun i -> to_process := MonoMap.add (i,[]) (Felix i) (!to_process)) roots;
  
  let processed = ref MonoMap.empty in

  (* new bsym_table *)
  let nutab = Flx_bsym_table.create () in


  while not (MonoMap.is_empty (!to_process)) do
    let (i,ts),target = MonoMap.choose (!to_process) in
    assert (not (MonoMap.mem (i,ts) (!processed) ));
    begin try List.iter (check_mono bsym_table) ts with _ -> assert false end;

    to_process := MonoMap.remove (i,ts) (!to_process);
    processed := MonoMap.add (i,ts) target (!processed);

    match target with 
    | External ->
      if debug then print_endline ("External target, leave polymorphic "^ show bsym_table i);
      let parent,sym = Flx_bsym_table.find_with_parent bsym_table i in
      begin match parent with 
      | None -> ()
      | Some p -> 
        print_endline ("Expected primitive to have no parent, got "^ show bsym_table i);
      end;
      Flx_bsym_table.add nutab i None sym

    | Felix j ->
      assert (List.length ts > 0 || match target with Felix i -> i == j | _ -> true);
      assert (not (Flx_bsym_table.mem nutab j));
      mono_element debug syms to_process processed bsym_table nutab i ts j;

     
  done
  ;

  nutab
