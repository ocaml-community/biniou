(lang dune 1.10)
(name biniou)

(generate_opam_files true)
(license "BSD-3-Clause")
(maintainers "martin@mjambon.com")
(authors "Martin Jambon")
(implicit_transitive_deps false)

(package
 (name biniou)
 (depends
  easy-format
  (dune (>= 1.10))
  (ocaml (>= "4.02.3"))))
