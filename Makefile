PACTICIPANT ?= "pactflow-example-bi-directional-provider-soapui"
GITHUB_REPO := "pactflow/example-bi-directional-provider-soapui"
VERSION?=$(shell npx -y absolute-version)
BRANCH?=$(shell git rev-parse --abbrev-ref HEAD)

## ====================
## Demo Specific Example Variables
## ====================
OAS_PATH=oas/products.yml
REPORT_PATH?=project/reports/TEST-Product_API_TestSuite.xml
REPORT_FILE_CONTENT_TYPE?=text/xml
VERIFIER_TOOL?=soapui
ENDPOINT:=http://localhost:3001
# Docker command tested against linux(GH actions) / macosx locally
# Needs testing on windows
READY_RUNNER_DOCKER_PATH?=docker run --rm --network="host" -v=${PWD}/project:/project -e ENDPOINT=${ENDPOINT} -e COMMAND_LINE="'-e${ENDPOINT}' '-f/project/reports' -r -j /project/Project-1-soapui-project.xml" smartbear/soapuios-testrunner:latest
# RAPI_RUNNER can be set to local SoapUI installation if available, otherwise will default to docker
# RAPI_RUNNER=local
READY_API_LOCAL_INSTALLATION_PATH_MAC?=/Applications/SoapUI-5.7.0.app/Contents/java/app/bin/testrunner.sh
# Default installation paths for Linux/Windows to be added/tested
READY_API_LOCAL_INSTALLATION_PATH_LINUX?=TODO
READY_API_LOCAL_INSTALLATION_PATH_WIN?=TODO
READY_RUNNER_LOCAL_PATH_MAC?=${READY_API_LOCAL_INSTALLATION_PATH_MAC} -e${ENDPOINT} -f${PWD}/project/reports -r -j ${PWD}/project/Project-1-soapui-project.xml
# Commands need testing cross platform
READY_RUNNER_LOCAL_PATH_LINUX?=${READY_API_LOCAL_INSTALLATION_PATH_LINUX} -e${ENDPOINT} -r -j ${PWD}/project/Project-1-soapui-project.xml
READY_RUNNER_LOCAL_PATH_WIN?=${READY_API_LOCAL_INSTALLATION_PATH_WIN} -e${ENDPOINT} -r -j ${PWD}/project/Project-1-soapui-project.xml

## =====================
## Build/test tasks
## =====================

install: npm install 

test: 
	@echo "\n========== STAGE: test ✅ ==========\n"
	@echo "Running soapui tests against locally running provider"
	@npm run test


test-soapui:
	case "${RAPI_RUNNER}" in \
		local) 	case "${detected_OS}" in \
					Windows|MSYS) ${READY_RUNNER_LOCAL_PATH_WIN};; \
					Darwin) ${READY_RUNNER_LOCAL_PATH_MAC};; \
					Linux) ${READY_RUNNER_LOCAL_PATH_LINUX};; \
				esac;; \
		*) 	case "${detected_OS}" in \
				Windows|MSYS) ENDPOINT=http://host.docker.internal:3001 ${READY_RUNNER_DOCKER_PATH};; \
				Darwin) ENDPOINT=http://host.docker.internal:3001 ${READY_RUNNER_DOCKER_PATH};; \
				Linux) ${READY_RUNNER_DOCKER_PATH};; \
			esac;; \
	esac
## ====================
## CI tasks
## ====================

all: ci
all_docker: ci_docker
all_ruby_standalone: ci_ruby_standalone
all_ruby_cli: ci_ruby_cli

# Run the ci target from a developer machine with the environment variables
# set as if it was on Github Actions.
# Use this for quick feedback when playing around with your workflows.
ci: test_and_publish can_i_deploy $(DEPLOY_TARGET)

ci_ruby_cli:
	PACT_TOOL=ruby_cli make ci
ci_docker:
	PACT_TOOL=docker make ci
ci_ruby_standalone:
	PACT_TOOL=ruby_standalone make ci

test_and_publish:
	@if make test; then \
		EXIT_CODE=0 make publish_provider_contract; \
	else \
		EXIT_CODE=1 make publish_provider_contract; \
	fi; \

publish_provider_contract: 
	@echo "\n========== STAGE: publish-provider-contract (spec + results) ==========\n"
	${PACTFLOW_CLI_COMMAND} publish-provider-contract \
      ${OAS_PATH} \
      --provider ${PACTICIPANT} \
      --provider-app-version ${VERSION} \
      --branch ${BRANCH} \
      --content-type application/yaml \
      --verification-exit-code=${EXIT_CODE} \
      --verification-results ${REPORT_PATH} \
      --verification-results-content-type ${REPORT_FILE_CONTENT_TYPE}\
      --verifier ${VERIFIER_TOOL}

## =====================
## Deploy tasks
## =====================

# Only deploy from main/master
ifneq ($(filter $(BRANCH),main master),)
	DEPLOY_TARGET=deploy
else
	DEPLOY_TARGET=no_deploy
endif

deploy: deploy_app record_deployment
deploy_target: can_i_deploy $(DEPLOY_TARGET)
no_deploy:
	@echo "Not deploying as not on master branch"

can_i_deploy: 
	@echo "\n========== STAGE: can-i-deploy? 🌉 ==========\n"
	${PACT_BROKER_COMMAND} can-i-deploy \
	--pacticipant ${PACTICIPANT} \
	--version ${VERSION} \
	--to-environment production

deploy_app:
	@echo "\n========== STAGE: deploy 🚀 ==========\n"
	@echo "Deploying to prod"

record_deployment: 
	${PACT_BROKER_COMMAND} \
	record_deployment \
	--pacticipant ${PACTICIPANT} \
	--version ${VERSION} \
	--environment production

## =====================
## Multi-platform detection and support
## Pact CLI install/uninstall tasks
## =====================
SHELL := /bin/bash
PACT_TOOL?=docker
PACT_CLI_DOCKER_VERSION?=latest
PACT_CLI_VERSION?=latest
PACT_CLI_STANDALONE_VERSION?=1.89.00
PACT_CLI_DOCKER_RUN_COMMAND?=docker run --rm -v /${PWD}:/${PWD} -w ${PWD} -e PACT_BROKER_BASE_URL -e PACT_BROKER_TOKEN pactfoundation/pact-cli:${PACT_CLI_DOCKER_VERSION}
PACT_BROKER_COMMAND=pact-broker
PACTFLOW_CLI_COMMAND=pactflow

ifeq '$(findstring ;,$(PATH))' ';'
	detected_OS := Windows
else
	detected_OS := $(shell uname 2>/dev/null || echo Unknown)
	detected_OS := $(patsubst CYGWIN%,Cygwin,$(detected_OS))
	detected_OS := $(patsubst MSYS%,MSYS,$(detected_OS))
	detected_OS := $(patsubst MINGW%,MSYS,$(detected_OS))
endif

ifeq ($(PACT_TOOL),ruby_standalone)
# add path to standalone, and add bat if windows
	ifneq ($(filter $(detected_OS),Windows MSYS),)
		PACT_BROKER_COMMAND:="./pact/bin/${PACT_BROKER_COMMAND}.bat"
		PACTFLOW_CLI_COMMAND:="./pact/bin/${PACTFLOW_CLI_COMMAND}.bat"
	else
		PACT_BROKER_COMMAND:="./pact/bin/${PACT_BROKER_COMMAND}"
		PACTFLOW_CLI_COMMAND:="./pact/bin/${PACTFLOW_CLI_COMMAND}"
	endif
endif

ifeq ($(PACT_TOOL),docker)
# add docker run command path
	PACT_BROKER_COMMAND:=${PACT_CLI_DOCKER_RUN_COMMAND} ${PACT_BROKER_COMMAND}
	PACTFLOW_CLI_COMMAND:=${PACT_CLI_DOCKER_RUN_COMMAND} ${PACTFLOW_CLI_COMMAND}
endif


install-pact-ruby-cli:
	case "${PACT_CLI_VERSION}" in \
	latest) gem install pact_broker-client;; \
	"") gem install pact_broker-client;; \
		*) gem install pact_broker-client -v ${PACT_CLI_VERSION} ;; \
	esac

uninstall-pact-ruby-cli:
	gem uninstall -aIx pact_broker-client

install-pact-ruby-standalone:
	case "${detected_OS}" in \
	Windows|MSYS) curl -LO https://github.com/pact-foundation/pact-ruby-standalone/releases/download/v${PACT_CLI_STANDALONE_VERSION}/pact-${PACT_CLI_STANDALONE_VERSION}-win32.zip && \
		unzip pact-${PACT_CLI_STANDALONE_VERSION}-win32.zip && \
		./pact/bin/pact-mock-service.bat --help && \
		./pact/bin/pact-provider-verifier.bat --help && \
		./pact/bin/pactflow.bat help;; \
	Darwin) curl -LO https://github.com/pact-foundation/pact-ruby-standalone/releases/download/v${PACT_CLI_STANDALONE_VERSION}/pact-${PACT_CLI_STANDALONE_VERSION}-osx.tar.gz && \
		tar xzf pact-${PACT_CLI_STANDALONE_VERSION}-osx.tar.gz && \
		./pact/bin/pact-mock-service --help && \
		./pact/bin/pact-provider-verifier --help && \
		./pact/bin/pactflow help;; \
	Linux) curl -LO https://github.com/pact-foundation/pact-ruby-standalone/releases/download/v${PACT_CLI_STANDALONE_VERSION}/pact-${PACT_CLI_STANDALONE_VERSION}-linux-x86_64.tar.gz && \
		tar xzf pact-${PACT_CLI_STANDALONE_VERSION}-linux-x86_64.tar.gz && \
		./pact/bin/pact-mock-service --help && \
		./pact/bin/pact-provider-verifier --help && \
		./pact/bin/pactflow help;; \
	esac

## ======================
## Misc
## ======================


.PHONY: start stop test