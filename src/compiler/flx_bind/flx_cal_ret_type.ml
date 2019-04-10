open Flx_util
open Flx_list
open Flx_ast
open Flx_types
open Flx_btype
open Flx_bparameter
open Flx_bexpr
open Flx_bbdcl
open Flx_print
open Flx_exceptions
open Flx_set
open Flx_mtypes2
open Flx_typing
open Flx_typing2
open Flx_unify
open Flx_beta
open Flx_generic
open Flx_overload
open Flx_tpat
open Flx_lookup_state
open Flx_name_map
open Flx_btype_occurs
open Flx_btype_subst
open Flx_bid

let debug = false

let cal_ret_type' 
  build_env
  bind_type'
  bind_expression' 
  state bsym_table (rs:recstop) index args 
=
  let mkenv i = build_env state bsym_table (Some i) in
  let env = mkenv index in
  let parent = Flx_sym_table.find_parent state.sym_table index in
  match (get_data state.sym_table index) with
  | { Flx_sym.id=id;
      sr=sr;
      dirs=dirs;
      symdef=SYMDEF_function ((ps,_),rt,effects,props,exes)
    } ->
(*
print_endline ("+++++++++++++++++++++++++++++");
print_endline ("Cal ret type of " ^ id ^ "<" ^ string_of_int index ^ "> at " ^ Flx_srcref.short_string_of_src sr);
print_endline ("+++++ UNBOUND return type is " ^ string_of_typecode rt);
*)
    let rt = bind_type' state bsym_table env rs sr rt args mkenv in
    let rt = beta_reduce "flx_lookup: cal_ret_type" state.counter bsym_table sr rt in
    let pvtype = match rt with BTYP_variant _ -> true | _ -> false in
(*
    if pvtype then print_endline (id ^ " has pv type " ^ sbt bsym_table rt);
*)
    let ret_type = ref rt in
    let return_counter = ref 0 in
(*
print_endline ("+++++ return type is " ^ sbt bsym_table rt);
*)
(* HACK! We skip instructions when the match skip level is > 0, except
  for begin/end match cases. This means once we have a GadtUnificationFailure,
  return types (and all other code) for that match case are ignored.

  This is a hack because in theory, a return statement could already
  have been processed before the EXPR_ctor_arg that triggered the 
  GadtUnificationFailure. Technically we should defer committing the
  return type until the final end_match_case is seen without a unification
  error. However this is a bit tricky, because matches can be nested.

  So the hack should work some of the time at least! Its likely the
  unification error will happen first (because of the way the code
  is generated by the desugaring routines).

  In any case it is still a hack, because we might get a binding failure
  masking a unification failure, and we ony stop on a unification failure,
  not some other binding failure. We know recursion will cause a failure.
  That's WHY this routine exists, to calculate the return type for all
  functions so that subsequent binding should work without a failure.
*)
    let match_skip_level = ref 0 in
    List.iter
    (fun exe -> match exe with
    | (sr,EXE_begin_match_case) -> 
(*
       print_endline "BEGIN MATCH CASE";
*)
       if !match_skip_level > 0 then incr match_skip_level;
       ()

    | (sr,EXE_end_match_case) -> 
(*
       print_endline "END MATCH CASE";
*)
       if !match_skip_level > 0 then decr match_skip_level;
       ()

    | (_,exe) when !match_skip_level > 0 -> 
(*
      print_endline ("---- Skipping branch containing " ^ string_of_exe 2 exe);
*)
     ()

    | (sr,EXE_fun_return e) ->
(*
print_endline ("Cal ret type of " ^ id ^ " got return: " ^ string_of_expr e);
*)
      incr return_counter;
      begin try
        let t =
          (* this is bad code .. we lose detection
          of errors other than recursive dependencies ..
          which shouldn't be errors anyhow ..
          *)
(*
print_endline ("Calling bind_epression'");
*)
(* NOTE: this is NOT necessary if the expression is an explicit coercion! In that case
we should just find the type being coerced to! 
*)
            snd
            (
              bind_expression' state bsym_table env
              { rs with idx_fixlist = index::rs.idx_fixlist }
              e []
            )
        in
(*
print_endline "Flx_lookup: about to check calculated and registered return type";
print_endline ("Return type = " ^ Flx_btype.st !ret_type);
print_endline ("Return expression type = " ^ Flx_btype.st t);
*)
        if pvtype then
          () (* use the declared return type, let the coercion be inserted later *) 
        else
        let result = Flx_do_unify.do_unify
           state.counter
           state.varmap
           state.sym_table
           bsym_table
           !ret_type
           t
          (* the argument order is crucial *)
        in 
        if result then
          let t' = varmap_subst state.varmap !ret_type in
(*
print_endline (" %%%%% Setting return type to " ^ sbt bsym_table t');
*)
          ret_type := t'
        else begin
          (*
          print_endline
          (
            "[cal_ret_type2] Inconsistent return type of " ^ id ^ "<"^string_of_int index^">" ^
            "\nGot: " ^ sbt bsym_table !ret_type ^
            "\nAnd: " ^ sbt bsym_table t
          )
          ;
          *)
          clierrx "[flx_bind/flx_cal_ret_type.ml:159: E105a] " sr
          (
            "[cal_ret_type2] Inconsistent return type of " ^ id ^ "<" ^
            string_of_bid index ^ ">" ^
            "\nGot: " ^ str_of_btype !ret_type ^ "\n  = " ^ sbt bsym_table !ret_type ^
            "\nAnd: " ^ str_of_btype t ^ "\n  = " ^ sbt bsym_table t
          )
        end
      with
        | Stack_overflow -> failwith "[cal_ret_type] Stack overflow"
        | Expr_recursion e -> (* print_endline "Expr recursion"; *)  ()
        | Free_fixpoint t ->  (* print_endline "Free fixpoint"; *) ()
        | Unresolved_return (sr,s) -> (* print_endline "Unresolved return"; *) ()
        | SimpleNameNotFound (sr,name,s) as e -> 
(*
          print_endline ("Whilst calculating return type:\nSimple name "^name^" not found"); 
*)
          raise e
        | ClientError (sr2,s) as e -> 
         print_endline ("ClientError Whilst calculating return type:\n"^s);
         raise (ClientError2 (sr,sr2,"Whilst calculating return type:\n"^s))

        | ClientError2 (sr,sr2,s) as e -> 
          print_endline ("ClientError2 Whilst calculating return type:\n"^s);
          raise e
        | GadtUnificationFailure ->
(*
         print_endline "GADT UNIFICATION ERROR BINDING RETURN STATEMENT";
*)
         match_skip_level := 1;
         ()
        | x ->
        print_endline ("FLx_cal_ret_type:  .. Unable to compute type of " ^ string_of_expr e);
        print_endline ("Reason: " ^ Printexc.to_string x);
        let sr = src_of_expr e in
        print_endline (Flx_srcref.long_string_of_src sr);
        raise x 
      end
    | (sr,exe) -> 
(*
      print_endline ("Cal ret type handling " ^ string_of_exe 2 exe);
*)
      begin try
        let be e =
          bind_expression' state bsym_table env
          { rs with idx_fixlist = index::rs.idx_fixlist }
          e []
       in
       (* FIXME: we need to get even MORE precise, we ONLY want to
          bind EXPR_ctor_arg expressions!
       *)
       let be' e = let _ = be e in () in
       let ign x = () in
       Flx_maps.iter_exe ign ign be' exe;
(*
       print_endline "EXE BOUND";
*)
      with 
      | GadtUnificationFailure -> 
(*
        print_endline ("******* Binding failed with GadtUnificationError");
*)
        match_skip_level := 1

      | exn -> 
(*
        print_endline ("BINDING EXE FAILED with " ^ Printexc.to_string exn);
*)
     ()
      end;
      ()
    )
    exes
    ;
    if !return_counter = 0 then (* it's a procedure .. *)
    begin
(*
print_endline ("Flx_lookup about to do unify[2]");
*)
      let mgu = Flx_do_unify.do_unify
        state.counter
        state.varmap
        state.sym_table
        bsym_table
        !ret_type
        (btyp_void ())
      in
      ret_type := varmap_subst state.varmap !ret_type
    end
    ;
    (* not sure if this is needed or not ..
      if a type variable is computed during evaluation,
      but the evaluation fails .. substitute now
    ret_type := varmap_subst state.varmap !ret_type
    ;
    *)
    (*
    let ss = ref "" in
    Hashtbl.iter
    (fun i t -> ss:=!ss ^si i^ " --> " ^sbt bsym_table t^ "\n")
    state.varmap;
    print_endline ("state.varmap=" ^ !ss);
    print_endline ("  .. ret type index " ^ si index ^ " = " ^ sbt bsym_table !ret_type);
    *)
    !ret_type

  | _ -> assert false


