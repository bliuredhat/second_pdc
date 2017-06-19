
_default:
	@echo Please specify a target:
	@grep -E '^[a-z]+[a-z_]*:' Makefile | cut -d: -f1 | xargs -n1 echo make

#---------------------------------------------------------------------

OPT_VERBOSE = -vv
INV_SERVERS = --inventory inventory/et-servers
INV_SLAVES = --inventory inventory/et-jenkins-slaves
PLAY = ansible-playbook $(OPT_VERBOSE)

#---------------------------------------------------------------------

# Default is to do a dry run. Set this to deploy for real.
ifndef REALLY
	EXTRA_VARS += dry_run=yes
endif

# If the build to install is older than the one already installed then
# yum install won't install it and you have to use yum downgrade.
ifdef DOWNGRADE
	EXTRA_VARS += yum_downgrade=yes
endif

# Specify a build number for Jenkins build deploys
# If you leave it blank it will find the latest one automatically
ifdef BUILD
	EXTRA_VARS += jenkins_build_number=$(BUILD)
	EXTRA_VARS += build_source=jenkins
else
# Specify the version for brew build deploys
# VER is required, eg VER=3.10.5.0
# REL defaults to zero if you don't set it
ifdef VER
	EXTRA_VARS += ver=$(VER)
	EXTRA_VARS += build_source=brew
endif
ifdef REL
	EXTRA_VARS += rel=$(REL)
endif
endif

# For release candidate builds. Affects the notification text only.
ifdef RC
	EXTRA_VARS += is_release_candidate=yes
	# The default is MODIFIED, but for release candidate builds we
	# usually want to list all VERIFIED bugs.
	EXTRA_VARS += bug_list_status=VERIFIED
endif

# Set this to skip email notifications
ifdef SKIP_EMAIL
	EXTRA_VARS += skip_email=yes
endif

# Set this to skip the bug list lookup
ifdef SKIP_BUG_LIST
	EXTRA_VARS += skip_bug_list=yes
endif

# Set this to test email notifications during a dry run
ifdef FORCE_EMAIL
	EXTRA_VARS += force_email=yes
endif

DEPLOY_BUILD = $(PLAY) playbooks/et-server/devel-deploy.yml $(INV_SERVERS) --ask-become-pass --extra-vars "$(EXTRA_VARS)"

TO_DEVEL_ALL = --limit et-devel-servers
TO_DEVEL_0 = --limit errata-devel-0
TO_DEVEL_1 = --limit errata-devel-1

# Bug lists are generally useful for devel deploys only so always skip them for QE deploys
TO_QE = --limit errata-qe --extra-vars skip_bug_list=yes

devel_deploy:
	$(DEPLOY_BUILD) $(TO_DEVEL_ALL)

devel_deploy_0:
	$(DEPLOY_BUILD) $(TO_DEVEL_0)

devel_deploy_1:
	$(DEPLOY_BUILD) $(TO_DEVEL_1)

qe_deploy:
	$(DEPLOY_BUILD) $(TO_QE)

#---------------------------------------------------------------------

fetch_prod_logs:
	$(PLAY) playbooks/et-server/fetch-logs.yml $(INV_SERVERS) --ask-become-pass --limit errata-prod

#---------------------------------------------------------------------

JENKINS_SLAVE = $(PLAY) playbooks/et-jenkins-slave/*.yml $(INV_SLAVES) --limit $(LIMIT) --ask-vault-pass --ask-become-pass

_jenkins_slave:
	$(JENKINS_SLAVE)

jenkins_slave:
	@if [ -n "$$SLAVE" ]; then \
		$(MAKE) --no-print-directory _jenkins_slave LIMIT=docker-$$SLAVE ;\
	else \
		echo Please specify a slave id using SLAVE=NN ;\
	fi

# (works if there is a group var that matches your hostname)
jenkins_slave_local:
	@$(MAKE) --no-print-directory _jenkins_slave LIMIT=`hostname --short`

#---------------------------------------------------------------------

# arg 1: "playbooks/some-playbook/"
define ROLES_template =

 $(1)roles: $(1)rolesfile
	ansible-galaxy install --force -r $$< -p $$@
	touch $$@

 clean_$(1)roles:
	rm -rf $(1)roles

 ALL_ROLES += $(1)roles

 ALL_CLEAN_ROLES += clean_$(1)roles
endef

$(foreach rolesfile,$(wildcard playbooks/*/rolesfile),$(eval $(call ROLES_template,$(dir $(rolesfile)))))

.PHONY: roles clean_roles

# Install all roles from rolesfiles
roles: $(ALL_ROLES)

# Remove all installed roles
clean_roles: $(ALL_CLEAN_ROLES)
