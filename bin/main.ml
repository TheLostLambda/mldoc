open Mldoc
open Mldoc.Parser
open Mldoc.Conf
open Lwt
open Cmdliner

(* stdin *)
let read_lines () = Lwt_io.read_lines Lwt_io.stdin |> Lwt_stream.to_list

(* file *)
let from_file filename = Lwt_io.lines_of_file filename |> Lwt_stream.to_list

let generate backend output _opts filename =
  let extension = Filename.extension filename in
  let format =
    match extension with
    | ".markdown"
    | ".md" ->
      Markdown
    | _ -> Org
  in
  let lines =
    if filename = "-" then
      read_lines ()
    else
      from_file filename
  in
  lines >>= function
  | lines ->
    let config =
      { toc = true
      ; parse_outline_only = true
      ; heading_number = true
      ; keep_line_break = false
      ; format
      ; heading_to_list = true
      ; exporting_keep_properties = true
      ; inline_type_with_pos = false
      ; inline_skip_macro = false
      ; export_md_indent_style = Dashes
      ; export_md_remove_options = []
      ; hiccup_in_block = true
      }
    in
    let ast = parse config (String.concat "\n" lines) in
    let document = Document.from_ast None ast in
    let export = Exporters.find backend in
    let module E = (val export : Exporter.Exporter) in
    let output =
      if output = "" then
        E.default_filename filename
      else
        output
    in
    let fdout =
      if output = "-" then
        stdout
      else
        open_out output
    in
    (* FIXME: parse *)
    let result = Exporters.run ~refs:None export config document fdout in
    return result

(* Cmd liner part *)

(* Commonon options *)
let output =
  let doc = "Write the generated file to $(docv). " in
  Arg.(value & opt string "" & info [ "o"; "output" ] ~docv:"OUTPUT-FILE" ~doc)

let backend =
  let doc = "Uses $(docv) to generate the output. (`-` for stdout)" in
  Arg.(value & opt string "html" & info [ "b"; "backend" ] ~docv:"BACKEND" ~doc)

let filename =
  let doc = "The input filename to use. (`-` for stdin) " in
  Arg.(value & pos 0 string "-" & info [] ~docv:"FILENAME" ~doc)

let options =
  let doc =
    "Extra option to use to configure the behaviour. (Can be used multiple \
     times)"
  in
  Arg.(
    value
    & opt_all (pair ~sep:'=' string string) []
    & info [ "x"; "option" ] ~docv:"OPTIONS" ~doc)

let cmd = Term.(const generate $ backend $ output $ options $ filename)

let doc = "converts org-mode or markdown files into various formats"

let options = []

let man =
  [ `S "DESCRIPTION"
  ; `P
      "$(tname) can currently converts org-mode or markdown files into other \
       formats such as\n\
      \       HTML."
  ]
  @ options

let infos = Cmd.info "mldoc" ~version:"0" ~doc ~man
let main () =
  match Cmd.v infos cmd |> Cmd.eval_value with
  | Ok (`Ok expr) -> Lwt_main.run expr
  | _ -> exit 1

let () =
  let _ = Printexc.record_backtrace true in
  if not !Sys.interactive then main ()
