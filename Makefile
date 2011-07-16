# $Id$

VERSION = 1.0.1+dev

FLAGS = -dtypes
PACKS = easy-format

.PHONY: default all opt install doc test
default: all opt test_biniou META
all: biniou.cma
opt: biniou.cmxa bdump

test: test_biniou
	./test_biniou

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

test_biniou: biniou.cmxa test_biniou.ml
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
          $$(ls $(MLI) $(CMI) $(CMO) $(CMX) $(O) \
             biniou.cma biniou.cmxa biniou.a)

uninstall:
	test ! -f $(BINDIR)/bdump || rm $(BINDIR)/bdump
	test ! -f $(BINDIR)/bdump.exe || rm $(BINDIR)/bdump.exe 
	ocamlfind remove biniou

.PHONY: clean

clean:
	rm -f *.o *.a *.cm[ioxa] *.cmxa *~ *.annot 
	rm -f bdump bdump.exe test_biniou test_biniou.exe META
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
