.PHONY: html clean

html:
	./scripts/build-ar5iv.sh

clean:
	rm -rf _site *.latexml.log
