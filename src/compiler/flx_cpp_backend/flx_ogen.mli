(** GC shape object generator *)

val gen_offset_tables:
  Flx_mtypes2.sym_state_t ->
  Flx_bsym_table.t ->
  Flx_btype.t list ->
  string ->
  string (*  tables *)

