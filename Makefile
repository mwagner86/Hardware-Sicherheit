.PHONY: all paper expose draft einleitung1 einleitung2 einleitungen analyse clean fullclean

LATEXMK     = latexmk
LATEXMK_FLAGS = -pdf -interaction=nonstopmode -file-line-error -synctex=1
CLEAN_AUX   = rm -f *.aux *.bbl *.blg *.log *.out *.toc *.fdb_latexmk *.fls \
                    *.synctex.gz *.run.xml *-blx.bib *.bcf

all: paper expose draft einleitungen analyse

paper:
	@echo "Building Paper..."
	cd paper && $(LATEXMK) $(LATEXMK_FLAGS) main.tex

expose:
	@echo "Building Expose..."
	cd project/expose && $(LATEXMK) $(LATEXMK_FLAGS) expose_hardware_security.tex

draft:
	@echo "Building Literatur Draft..."
	cd paper && $(LATEXMK) $(LATEXMK_FLAGS) literatur_recherche_draft.tex

einleitung1:
	@echo "Building Einleitung (Erste Version)..."
	cd paper/einleitungen && BIBINPUTS=..: $(LATEXMK) $(LATEXMK_FLAGS) einleitung_erste_version.tex

einleitung2:
	@echo "Building Einleitung (Zweite Version)..."
	cd paper/einleitungen && BIBINPUTS=..: $(LATEXMK) $(LATEXMK_FLAGS) einleitung_zweite_version.tex

einleitungen: einleitung1 einleitung2

analyse:
	@echo "Building Analysis Protocol..."
	cd project/notes && $(LATEXMK) $(LATEXMK_FLAGS) analyse_protokoll.tex

clean:
	@echo "Cleaning auxiliary files..."
	cd paper              && $(LATEXMK) -c && $(CLEAN_AUX)
	cd paper/einleitungen && $(LATEXMK) -c && $(CLEAN_AUX)
	cd project/expose     && $(LATEXMK) -c && $(CLEAN_AUX)
	cd project/notes      && $(LATEXMK) -c && $(CLEAN_AUX)

fullclean: clean
	@echo "Removing PDF files..."
	cd paper              && $(LATEXMK) -C && rm -f *.pdf
	cd paper/einleitungen && $(LATEXMK) -C && rm -f *.pdf
	cd project/expose     && $(LATEXMK) -C && rm -f *.pdf
	cd project/notes      && $(LATEXMK) -C && rm -f *.pdf