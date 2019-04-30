# Define build harness branch
BUILD_HARNESS_ORG = hans-moen
BUILD_HARNESS_BRANCH = hktest

# Define the template and vars file used by the build-harness terraform module
TERRAFORM_DIR ?=
TERRAFORM_VARS_FILE ?=

# GITHUB_USER containing '@' char must be escaped with '%40'
GITHUB_USER := $(shell echo $(GITHUB_USER) | sed 's/@/%40/g')
GITHUB_TOKEN ?=

# There are many permutations of templates and tfvar example files.
# Only run the templates that has changes
DO_DEPLOY ?= $(shell git diff --name-only $(TRAVIS_COMMIT_RANGE) | grep -q -E "$(shell basename $(TERRAFORM_DIR))/(.*.tf)|(.*.tfvars)" && echo yes || echo no)


.PHONY: default
default:: init;

.PHONY: init\:
init::
ifndef GITHUB_USER
	$(info GITHUB_USER not defined)
	exit -1
endif
	$(info Using GITHUB_USER=$(GITHUB_USER))
ifndef GITHUB_TOKEN
	$(info GITHUB_TOKEN not defined)
	exit -1
endif
ifndef TERRAFORM_DIR
	$(info TERRAFORM_DIR not defined)
	exit -1
endif
	$(info Using TERRAFORM_DIR=$(TERRAFORM_DIR))
ifndef TERRAFORM_VARS_FILE
	$(info TERRAFORM_VARS_FILE not defined)
	exit -1
endif
	$(info Using TERRAFORM_VARS_FILE=$(TERRAFORM_VARS_FILE))

-include $(shell curl -so .build-harness -H "Authorization: token $(GITHUB_TOKEN)" -H "Accept: application/vnd.github.v3.raw" "https://raw.github.ibm.com/ICP-DevOps/build-harness/master/templates/Makefile.build-harness"; echo .build-harness)

.PHONY: validate-tf
## Validate a given terraform template directory without deploying
validate-tf:
	@$(SELF) -s terraform:validate TERRAFORM_VARS_FILE=$(TERRAFORM_VARS_FILE) TERRAFORM_DIR=$(TERRAFORM_DIR)

.PHONY: deploy-icp-if-tfchange
deploy-icp-if-tfchange:
	git diff --name-only $(TRAVIS_COMMIT_RANGE)
ifeq "$(DO_DEPLOY)" "no"
	$(info No changes in templates for or example tfvars in $(basename $(TERRAFORM_DIR)), just doing basic syntax validation.)
	$(SELF) validate-tf
else
		$(SELF) deploy-icp
endif

.PHONY: deploy-icp
## Deploy a given terraform template directory with a given terraform VARS file
deploy-icp:
	@$(SELF) -s terraform:apply TERRAFORM_VARS_FILE=$(TERRAFORM_VARS_FILE) TERRAFORM_DIR=$(TERRAFORM_DIR)

.PHONY: validate-icp
validate-icp:
ifeq "$(DO_DEPLOY)" "no"
	$(info ICP Not deployed, skipping validation tests)
else ifeq "$(TRAVIS_TEST_RESULT)" "1"
	$(error Will not run validation on failed deployment)
else
	$(info Running validation test)
	@export SERVER=$(shell $(SELF) -s terraform:output TERRAFORM_OUTPUT_VAR=icp_console_server) ; \
	export USERNAME=$(shell $(SELF) -s terraform:output TERRAFORM_OUTPUT_VAR=icp_admin_username) ; \
	export PASSWORD=$(shell $(SELF) -s terraform:output TERRAFORM_OUTPUT_VAR=icp_admin_password) ; \
	$(SELF) -s validateicp:runall
endif


.PHONY: cleanup
## Delete the environment
cleanup:
	@$(SELF) -s terraform:destroy
