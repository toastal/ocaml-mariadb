(** OCaml-MariaDB is a library with OCaml bindings for MariaDB's
    libmysqlclient, including support for its nonblocking API. While you
    need this MariaDB's libmysqlclient to build OCaml-MariaDB, it should
    be possible to use it with the regular libmysqlclient from the MySQL
    project, as long as you don't try to use the nonblocking API.

    These bindings are restricted to MariaDB's prepared statement APIs,
    as they provide support for typed query parameters and results.
*)

(** The MariaDB interface, used both by the blocking and nonblocking versions
    of the API. *)
module type S = sig
  type error = int * string
    (** The type of errors that can result from MariaDB API calls. *)

  type 'a result = ('a, error) Pervasives.result
    (** The result of MariaDB API calls. *)

  (** This module defines a database field retrieved by a query. *)
  module Field : sig
    type t
      (** The type of fields. *)

    type time =
      { year : int
      ; month : int
      ; day : int
      ; hour : int
      ; minute : int
      ; second : int
      }
      (** The type of time-related fields, i.e. [DATE], [DATETIME] and
          [TIMESTAMP]. *)

    type value =
      [ `Int of int
      | `Float of float
      | `String of string
      | `Bytes of bytes
      | `Time of time
      | `NullInt of int option
      | `NullFloat of float option
      | `NullString of string option
      | `NullBytes of bytes option
      | `NullTime of time option
      ]

    val name : t -> string
      (** [name field] returns the field name of [field]. *)

    val value : t -> value
      (** [value field] returns the value associated with [field]. *)

    val null_value : t -> bool
      (** [null_value field] returns [true] if the value associated with
          [field] is [NULL]. *)

    val can_be_null : t -> bool
      (** [can_be_null field] returns [true] if values of [field] can assume
          the [NULL] value (i.e. the table definition does not specify
          [NOT NULL] for this field. *)

    (** {2 Value retrieval functions}

        The functions below simplify the unwrapping of OCaml values from
        fields. They raise [Failure] if the field is not of the expected
        type, but this should not be a problem as the type of a field is
        in all likelyhood known in advance by database users.
    *)

    val int : t -> int
    val float : t -> float
    val string : t -> string
    val bytes : t -> bytes
    val time : t -> time

    val null_int : t -> int option
    val null_float : t -> float option
    val null_string : t -> string option
    val null_bytes : t -> bytes option
    val null_time : t -> time option
  end

  (** A module representing database rows. Rows can be retrieved as different
      data structures, which as passed to the row retrieval functions from the
      [Res] module. There's built-in support for fetching rows as arrays and
      maps and hash tables of field name to field, but any module conforming
      to [Row.S] can be provided to those functions. *)
  module Row : sig
    module type S = sig
      type t
        (** The type of database rows. *)

      val build : int -> (int -> Field.t) -> t
        (** [build n f] creates a row of [n] fields built by the results of
            [f 0], [f 1], ..., [f (n-1)]. *)
    end

    module StringMap : Map.S with type key = string

    module Array : (S with type t = Field.t array)
      (** Rows as field arrays. *)

    module Map : (S with type t = Field.t StringMap.t)
      (** Rows as field name to [Field.t] maps. *)

    module Hashtbl : (S with type t = (string, Field.t) Hashtbl.t)
      (** Rows as field name to [Field.t] hash tables. *)
  end

  (** The module containing operations on MariaDB query results. *)
  module Res : sig
    type t
      (** The type of query results. *)

    val num_rows : t -> int
      (** [num_rows res] returns the number of rows in result [res] after
          the execution of a [SELECT]-type query. *)

    val affected_rows : t -> int
      (** [num_rows res] returns the number of affected rows in result [res]
          after the execution of an [INSERT] or [UPDATE]-type query. *)

    val fetch : (module Row.S with type t = 'r) -> t -> 'r option result
      (** [fetch (module M : Row.S) res] fetches the next available row
          from [res], returning it in as the data structure specified by
          module [M]. Returns [None] when no more rows are available. *)

    val stream : (module Row.S with type t = 'r) -> t -> 'r Stream.t result
      (** [stream (module M : Row.S) res] returns a stream of rows. *)
  end

  (** The module contains operations on MariaDB prepared statements. *)
  module Stmt : sig
    type t
      (** The type of prepared statement. *)

    type param =
      [ `Tiny of int
      | `Short of int
      | `Int of int
      | `Float of float
      | `Double of float
      | `String of string
      | `Blob of bytes
      ]
      (** The type of query parameters. *)

    val execute : t -> param array -> Res.t result
      (** [execute stmt params] executes the prepared statement [stmt]
          binding to it the query parameters [params] and returns a [Res.t],
          the query result. *)

    val close : t -> unit result
			(** [close stmt] closes the prepapred statement [stmt] and frees
					any allocated memory associated with it and its result. *)
  end

  type t
    (** The type of database handles. *)

  type flag =
    | Client_can_handle_expired_passwords
    | Compress
    | Found_rows
    | Ignore_sigpipe
    | Ignore_space
    | Interactive
    | Local_files
    | Multi_results
    | Multi_statements
    | No_schema
    | Odbc
    | Ssl
    | Remember_options

  type protocol =
    | Default
    | Tcp
    | Socket
    | Pipe
    | Memory

  type client_option =
    | Connect_timeout of int
    | Compress
    | Named_pipe of string
    | Init_command of string
    | Read_default_file of string
    | Read_default_group of string
    | Set_charset_dir of string
    | Set_charset_name of string
    | Local_infile of bool
    | Protocol of protocol
    | Shared_memory_base_name of string
    | Read_timeout of int
    | Write_timeout of int
    | Secure_auth of bool
    | Report_data_truncation of bool
    | Reconnect of bool
    | Ssl_verify_server_cert of bool
    | Plugin_dir of string
    | Default_auth of string
    | Bind of string
    | Ssl_key of string
    | Ssl_cert of string
    | Ssl_ca of string
    | Ssl_capath of string
    | Ssl_cipher of string
    | Ssl_crl of string
    | Ssl_crlpath of string
    | Connect_attr_reset
    | Connect_attr_add of string * string
    | Connect_attr_delete of string
    | Server_public_key of string
    | Enable_cleartext_plugin of bool
    | Can_handle_expired_passwords of bool
    | Use_thread_specific_memory of bool

  type server_option =
    | Multi_statements of bool

  val connect : ?host:string
             -> ?user:string
             -> ?pass:string
             -> ?db:string -> ?port:int -> ?socket:string
             -> ?flags:flag list -> unit
             -> t result
		(** Connect to a MariaDB server at the specified location with the specified
				flags and optionally select a database [db]. *)

  val close : t -> unit
    (** Close a database handle. *)

  val set_character_set : t -> string -> unit result
    (** Sets the connection character set to the given parameter. *)

  val select_db : t -> string -> unit result
    (** [select_db mariadb db] changes the current database to [db]. *)

  val change_user : t -> string -> string -> string option -> unit result
    (** [change_user mariadb user pass db] changes the connection user to
        [user] with password [password] and optionally change to database
        [db]. *)

  val dump_debug_info : t -> unit result
    (** Tells the MariaDB server to dump debug information to its logs. *)

  val set_client_option : t -> client_option -> unit
    (** Sets the given client option on the connection. *)

  val set_server_option : t -> server_option -> unit result
    (** Sets the given server option on the connection. *)

  val ping : t -> unit result
    (** Checks if the connection to the MariaDB server is working. If the
        [Reconnect] option is set and the connection is down, a reconnect
        attempt will be made. *)

  val autocommit : t -> bool -> unit result
    (** Sets autocommit mode on or off. *)

  val prepare : t -> string -> Stmt.t result
		(** [prepare mariadb query] creates a prepared statement for [query].
				The query may contain [?] as placeholders for parameters that
				can be bound by calling [Stmt.execute]. *)
end

(** The module for blocking MariaDB API calls. It should be possible to call
    functions from this module when using MySQL's or an older version of
    MariaDB's libmysqlclient. *)
module Blocking : S

(** This is the nonblocking MariaDB API. The interface contains a functor
    [Make] which, given a way to wait for a connection socket to be ready
    for reading or writing, returns a module with the same signature [S]
    as the traditional blocking API. *)
module Nonblocking : sig
  module Status : sig
    type t
      (** The type of a nonblocking operation status. *)

    val create : ?read:bool
              -> ?write:bool
              -> ?except:bool
              -> ?timeout:bool
              -> unit -> t
      (** Create a new status indicating which events have occured on the
          MariaDB connection socket. *)

    val read : t -> bool
      (** Indicates if a read event has occurred. *)

    val write : t -> bool
      (** Indicates if a write event has occurred. *)

    val except : t -> bool
      (** Indicates if an exceptional condition event has occurred. *)

    val timeout : t -> bool
      (** Indicates if a timeout has occurred. *)
  end

  type t = [`Nonblocking] Common.t
    (** The type of nonblocking database handles. *)

  val fd : t -> int
    (** The underlying file descriptor of the database connection. *)

  val timeout : t -> int
    (** If a nonblocking operation returns a [Status.t] indicating a timeout
        event, this function can be used to obtain the value, in seconds,
        after which the timeout has occured. *)

	(** Input module signature for the functor that generates a nonblocking
			connection module. *)
  module type Wait = sig
    val wait : t -> Status.t -> Status.t
			(** [wait mariadb status] must wait for the events set in [status]
					to occur in the [mariadb] connection and return a [Status.t]
					indicating which events have actually occured. *)
  end

	(** Functor that generates a nonblocking database interface, given a way
      to wait for connection socket events. *)
  module Make (W : Wait) : S
end
