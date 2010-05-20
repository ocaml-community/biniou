# $Id$

VERSION = 0.9.0

FLAGS = -dtypes
PACKS = easy-format

.PHONY: default all opt install doc
default: all opt test_biniou
all: biniou.cma
opt: biniou.cmxa bdump


ifndef PREFIX
  PREFIX = $(shell dirname $$(dirname $$(which ocamlfind)))
  export PREFIX
endif

ifndef BINDIR
  BINDIR = $(PREFIX)/bin
  export BINDIR
endif

META: META.in Makefile
	sed -e 's:@@VERSION@@:$(VERSION):' META.in > META

SOURCES = bi_util.ml bi_outbuf.mli bi_outbuf.ml bi_inbuf.mli bi_inbuf.ml \
          bi_vint.mli bi_vint.ml bi_io.mli bi_io.ml

MLI = $(filter %.mli, $(SOURCES))
ML = $(filter %.ml, $(SOURCES))
CMI = $(ML:.ml=.cmi)
CMO = $(ML:.ml=.cmo)
CMX = $(ML:.ml=.cmx)
O = $(ML:.ml=.o)

biniou.cma: $(SOURCES) Makefile
	ocamlfind ocamlc -a -o biniou.cma -package "$(PACKS)" $(SOURCES)

biniou.cmxa: $(SOURCES) Makefile
	ocamlfind ocamlopt -a -o biniou.cmxa -package "$(PACKS)" $(SOURCES)

bdump: $(SOURCES) bdump.ml
	ocamlfind ocamlopt -o bdump -package $(PACKS) -linkpkg \
		biniou.cmxa bdump.ml

test_biniou: $(SOURCES) test_biniou.ml
	ocamlfind ocamlopt -o test_biniou -package "$(PACKS) unix" -linkpkg \
		biniou.cmxa test_biniou.ml

doc: doc/index.html
doc/index.html: $(MLI)
	mkdir -p doc
	ocamlfind ocamldoc -d doc -html -package easy-format $(MLI)

install: META
	test ! -f bdump || cp bdump $(BINDIR)/
	test ! -f bdump.exe || cp bdump.exe $(BINDIR)/
	ocamlfind install biniou META \
          $$(ls $(MLI) $(CMI) $(CMO) $(CMX) $(O))

uninstall:
	test ! -f $(BINDIR)/bdump || rm $(BINDIR)/bdump
	test ! -f $(BINDIR)/bdump.exe || rm $(BINDIR)/bdump.exe 
	ocamlfind remove biniou

.PHONY: clean

clean:
	rm -f *.o *.a *.cm[ioxa] *.cmxa *~ *.annot 
	rm -f bdump bdump.exe test_biniou test_biniou.exe META
	rm -rf doc
