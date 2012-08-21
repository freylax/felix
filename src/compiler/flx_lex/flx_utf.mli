(** Internationalised identifier support *)
exception LexError of string

val ucs_id_ranges : (int * int) list
val utf8_to_ucn : string -> string
