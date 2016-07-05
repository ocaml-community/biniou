VERSION = 1.0.12

FLAGS = -g -annot -bin-annot
PACKS = easy-format

ifeq "$(shell ocamlfind ocamlc -config |grep os_type)" "os_type: Win32"
EXE=.exe
else
EXE=
endif

BEST = $(shell \
  if ocamlfind ocamlopt 2>/dev/null; then \
    echo .native; \
  else \
    echo .byte; \
  fi \
)

NATDYNLINK = $(shell \
  if [ -f `ocamlfind ocamlc -where`/dynlink.cmxa ]; then \
    echo YES; \
  else \
    echo NO; \
  fi \
)

ifeq "${NATDYNLINK}" "YES"
CMXS=biniou.cmxs
endif

.PHONY: default all byte opt install doc test
default: all test_biniou$(EXE)

ifeq "$(BEST)" ".native"
all: byte opt doc META
else
all: byte doc META
endif

byte: biniou.cma bdump.byte
opt: biniou.cmxa $(CMXS) bdump.native

test: test_biniou$(EXE)
	./$<

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

SOURCES = bi_util.mli bi_util.ml \
          bi_share.mli bi_share.ml \
          bi_outbuf.mli bi_outbuf.ml bi_inbuf.mli bi_inbuf.ml \
          bi_vint.mli bi_vint.ml bi_io.mli bi_io.ml \
          bi_dump.ml bi_stream.mli bi_stream.ml

MLI = $(filter %.mli, $(SOURCES))
ML = $(filter %.ml, $(SOURCES))
CMI = $(MLI:.mli=.cmi)
CMT = $(MLI:.mli=.cmt)
ANNOT = $(MLI:.mli=.annot)
CMO = $(ML:.ml=.cmo)
CMX = $(ML:.ml=.cmx)
O = $(ML:.ml=.o)

biniou.cma: $(SOURCES) Makefile
	ocamlfind ocamlc -a $(FLAGS) -o biniou.cma \
		-package "$(PACKS)" $(SOURCES)

biniou.cmxa: $(SOURCES) Makefile
	ocamlfind ocamlopt -a $(FLAGS) \
		-o biniou.cmxa -package "$(PACKS)" $(SOURCES)

biniou.cmxs: biniou.cmxa
	ocamlfind ocamlopt -shared -linkall -I . -o $@ $^

bdump.byte: biniou.cma bdump.ml
	ocamlfind ocamlc -o $@ $(FLAGS) \
		-package $(PACKS) -linkpkg $^

bdump.native: biniou.cmxa bdump.ml
	ocamlfind ocamlopt -o $@ $(FLAGS) \
		-package $(PACKS) -linkpkg $^

test_biniou.byte: biniou.cma test_biniou.ml
	ocamlfind ocamlc -o $@ $(FLAGS) \
		-package "$(PACKS) unix" -linkpkg $^

test_biniou.native: biniou.cmxa test_biniou.ml
	ocamlfind ocamlopt -o $@ $(FLAGS) \
		-package "$(PACKS) unix" -linkpkg $^

%$(EXE): %$(BEST)
	cp $< $@

doc: doc/index.html
doc/index.html: $(MLI)
	mkdir -p doc
	ocamlfind ocamldoc -d doc -html -package easy-format $(MLI)

install: META byte
	if [ -f bdump.native ]; then \
		cp bdump.native $(BINDIR)/bdump$(EXE); \
	else \
		cp bdump.byte $(BINDIR)/bdump$(EXE); \
	fi
	ocamlfind install biniou META \
	  $(MLI) $(CMI) $(CMT) $(ANNOT) $(CMO) biniou.cma \
	  -optional $(CMX) $(O) biniou.cmxa biniou.a biniou.cmxs

uninstall:
	rm -f $(BINDIR)/bdump{.exe,}
	ocamlfind remove biniou

.PHONY: clean

clean:
	rm -f *.o *.a *.cm[ioxa] *.cmxa *~ *.annot META
	rm -f {bdump,test_biniou}{.exe,.byte,.native,}
	rm -rf doc
	rm -f test.bin test_channels.bin

SUBDIRS =
SVNURL = svn://svn.forge.ocamlcore.org/svnroot/biniou/trunk/biniou

.PHONY: archive
archive:
	@echo "Making archive for version $(VERSION)"
	@if [ -z "$$WWW" ]; then \
		echo '*** Environment variable WWW is undefined ***' >&2; \
		exit 1; \
	fi
	@if [ -n "$$(svn status -q)" ]; then \
		echo "*** There are uncommitted changes, aborting. ***" >&2; \
		exit 1; \
	fi
	$(MAKE) && ./bdump -help > $$WWW/bdump-help.txt
	mkdir -p $$WWW/biniou-doc
	$(MAKE) doc && cp doc/* $$WWW/biniou-doc/
	rm -rf /tmp/biniou /tmp/biniou-$(VERSION) && \
		cd /tmp && \
		svn co "$(SVNURL)" && \
		for x in "." $(SUBDIRS); do \
			rm -rf /tmp/biniou/$$x/.svn; \
		done && \
		cd /tmp && cp -r biniou biniou-$(VERSION) && \
		tar czf biniou.tar.gz biniou && \
		tar cjf biniou.tar.bz2 biniou && \
		tar czf biniou-$(VERSION).tar.gz biniou-$(VERSION) && \
		tar cjf biniou-$(VERSION).tar.bz2 biniou-$(VERSION)
	mv /tmp/biniou.tar.gz /tmp/biniou.tar.bz2 ../releases
	mv /tmp/biniou-$(VERSION).tar.gz \
		/tmp/biniou-$(VERSION).tar.bz2 ../releases
	cp ../releases/biniou.tar.gz $$WWW/
	cp ../releases/biniou.tar.bz2 $$WWW/
	cp ../releases/biniou-$(VERSION).tar.gz $$WWW/
	cp ../releases/biniou-$(VERSION).tar.bz2 $$WWW/
	cd ../releases && \
		svn add biniou.tar.gz biniou.tar.bz2 \
			biniou-$(VERSION).tar.gz biniou-$(VERSION).tar.bz2 && \
		svn commit -m "biniou version $(VERSION)"
	cp LICENSE $$WWW/biniou-license.txt
	cp Changes $$WWW/biniou-changes.txt
	cp biniou-format.txt $$WWW/biniou-format.txt
	echo 'let biniou_version = "$(VERSION)"' \
		> $$WWW/biniou-version.ml
