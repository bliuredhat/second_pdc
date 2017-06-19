#
# Product Pages information here:
#  https://docs.engineering.redhat.com/display/EPM/Product+Pages+User+Guide
#  https://docs.engineering.redhat.com/display/HTD/HSS+products+sync+to+PP+guide
#

CVSROOT = :gserver:$(USER)@cvs.devel.redhat.com:/cvs/ecs

BASE_DIR = cvs/program/errata
DIR_NAME = errata-$(MAJOR).$(MINOR)-$(MAINT)
TJP_FILE = errata-$(MAJOR)-$(MINOR)-$(MAINT).tjp

ADD_MSG = Add schedule for Errata Tool $(MAJOR).$(MINOR).$(MAINT)
UPDATE_MSG = Update schedule for Errata Tool $(MAJOR).$(MINOR).$(MAINT)

_default:
	@echo Please specify one of these targets:
	@grep -E '^[a-z]+[a-z_]*:' Makefile | cut -d: -f1 | xargs -n1 echo make

go: cvs_update generate cvs_diff

cvs_update: kinit
	cd cvs; \
	export CVSROOT=$(CVSROOT); \
	cvs update

generate:
	ruby bin/generate-tjp.rb schedules.json

# (The '-' is to prevent make quitting on error code from cvs diff.)
cvs_diff: kinit
	-cd cvs; \
	export CVSROOT=$(CVSROOT); \
	cvs -q diff -kk program/Makefile program/errata/errata-*.*
	@echo Do cvs adds and commits as required
	@echo Note: If you add a new schedule you will need to add it to cvs/program/Makefile and update that also
	@echo Do this first:
	@echo 'export CVSROOT=$(CVSROOT)'

cvs_checkout: kinit
	mkdir -p cvs
	cd cvs; \
	export CVSROOT=$(CVSROOT); \
	cvs co program/common; \
	cvs co program/errata; \
	cvs co program/Makefile

build_all:
	for f in $(BASE_DIR)/errata-*.*; do cd $$f; make; cd -; done

view_all:
	for f in $(BASE_DIR)/errata-*.*; do cd $$f; TaskJugglerUI *.tjp; cd -; done

build_one: generate _versionset
	cd $(BASE_DIR)/$(DIR_NAME); make

view_one: build_one
	TaskJugglerUI $(BASE_DIR)/$(DIR_NAME)/$(TJP_FILE)

kinit:
	kinit

clean:
	rm -rf cvs

#--------------------------------------------------------------------

# Use this when you've added a new release
# (Remember to add it to cvs/program/Makefile first)
commit_new: _versionset
	export CVSROOT=$(CVSROOT); \
	cd $(BASE_DIR); \
	cvs add $(DIR_NAME); \
	cd $(DIR_NAME); \
	cvs add $(TJP_FILE) Makefile; \
	cvs commit -m "$(ADD_MSG)" $(TJP_FILE) Makefile ../../Makefile

# Use this when you've updated an existing release
commit_update: _versionset
	export CVSROOT=$(CVSROOT); \
	cd $(BASE_DIR)/$(DIR_NAME); \
	cvs commit -m "$(UPDATE_MSG)" $(TJP_FILE)

_versionset: _ensureset-MAJOR _ensureset-MINOR _ensureset-MAINT

# Ensure a particular environment variable was provided.
# Show a message and exit if it isn't set.
_ensureset-%:
	@if [ ! -n "$$$*" ]; then \
		echo "Please set environment variable $*"; \
		exit 1; \
	fi
