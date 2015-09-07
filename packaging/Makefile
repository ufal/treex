default: usage

PACKAGES := Treex-Core Treex-Unilang Treex-EN Treex-CS Treex-JA Treex-Parser-MSTperl Treex-Doc

usage:
	echo 'Targets: cleanall buildall testall'

cleanall:
	for d in $(PACKAGES); do \
		echo "Package $$d"; \
		( cd $$d; $(MAKE) clean ); \
	done;

buildall:
	for d in $(PACKAGES); do \
		echo "Package $$d"; \
		( cd $$d; $(MAKE) build ); \
	done;

testall:
	for d in $(PACKAGES); do \
		echo "Package $$d"; \
		( cd $$d; $(MAKE) test ); \
	done;
