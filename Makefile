.PHONY: all paper expose clean fullclean

LATEXMK = latexmk
LATEXMK_FLAGS = -pdf -interaction=nonstopmode -file-line-error -synctex=1

all: paper expose

paper:
	@echo "Building Paper..."
	cd paper && $(LATEXMK) $(LATEXMK_FLAGS) main.tex

expose:
	@echo "Building Expose..."
	cd project/expose && $(LATEXMK) $(LATEXMK_FLAGS) expose_hardware_security.tex

clean:
	@echo "Cleaning auxiliary files..."
	cd paper && $(LATEXMK) -c && rm -f *.bbl *.blg *.synctex.gz *.run.xml *-blx.bib *.bcf
	cd project/expose && $(LATEXMK) -c && rm -f *.bbl *.blg *.synctex.gz *.run.xml *-blx.bib *.bcf

fullclean: clean
	@echo "Removing PDF files..."
	cd paper && $(LATEXMK) -C && rm -f *.pdf
	cd project/expose && $(LATEXMK) -C && rm -f *.pdf