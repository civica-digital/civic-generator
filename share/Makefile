# Rules
.DEFAULT_GOAL := help

.PHONY: dev ci \
	logs up down \
	bundle prepare test \
	analyze deploy build \
	push provide update \
	clean help

# Variables
DEPLOY_ENV    := staging
HOST          := localhost
REPOSITORY    := civica-digital/$(shell basename $(shell pwd))
TAG           := latest
WORKSPACE     := .
IMAGE         := $(REPOSITORY):$(TAG)
SED           := sed

# Use a different sed version for MacOS users
ifeq ($(shell uname -s), Darwin)
	SED := gsed
endif

# Targets

#: Setup your Docker development environment
dev: files bundle prepare
	@docker images --filter 'dangling=true' -q \
		| xargs docker rmi -f 2> /dev/null; true
	docker-compose up -d

#: Run the CI strategy (prepare, test, analyze)
ci: bundle prepare test analyze

#: Rebuild the image and install the gems
bundle:
	docker-compose build web
	@docker-compose down --remove-orphans 2> /dev/null; true
	docker-compose run --rm --no-deps web bundle install

#: Prepare the test environment and run migrations
prepare: files
	docker-compose run --rm web rake db:create test:prepare db:migrate db:seed

#: Run the test suite
test:
	docker-compose run --rm -e RAILS_ENV=test web rake spec

#: Run the static analysis suite
analyze:
	docker-compose run --rm --no-deps web rubocop
	docker-compose run --rm --no-deps web rails_best_practices
	docker-compose run --rm --no-deps web reek
	docker-compose run --rm --no-deps -e CI=true web brakeman --no-progress -q -w3 -z
	docker-compose run --rm --no-deps -e HOME=/tmp web bundle-audit check --update --ignore CVE-2017-5029

#: Run the deploy strategy (build, push, provide, update)
deploy: build push provide update

#: Build the staging/production Docker image
build:
	docker build \
		--tag $(IMAGE) \
		--pull=true $(WORKSPACE) \
		--build-arg release_commit=$(shell git rev-parse HEAD)
ifeq ($(DEPLOY_ENV), "staging")
	# Persist the image layers to speed the CI builds with cache
	docker build --tag $(IMAGE) $(REPOSITORY):latest
endif

#: Push the Docker image to the registry
push:
	@$(shell aws --profile docker ecr get-login --no-include-email)
	docker push $(IMAGE)

#: Provide the HOST with the provisions/
provide:
	scp -r deploy/$(DEPLOY_ENV)/provisions $(HOST):/var/www/{{project_name}}

#: Update the HOST containers with the given Docker IMAGE
update:
	ssh -o StrictHostKeyChecking=no \
		$(HOST) bash -l -s < deploy/$(DEPLOY_ENV)/scripts/update-container.sh $(IMAGE)

#: Remove dangling image
clean:
	@docker-compose down --remove-orphans
	@docker rmi -f $(IMAGE); true
	@docker images --filter 'dangling=true' -q | xargs docker rmi -f; true

#: Start the containers with docker-compose in background
up:
	@docker-compose up -d

#: Remove the containers in background
down:
	@docker-compose down --remove-orphans

#: See the logs of the application container
logs:
	@docker-compose logs -f --tail 25 web

#: Unlock the secrets using your GPG key
decrypt:
	@git-crypt unlock

files: docker-compose.override.yml
	mkdir -p tmp
	mkdir -p log

docker-compose.override.yml:
	@echo "version: '3'"      >> docker-compose.override.yml
	@echo "services:"         >> docker-compose.override.yml
	@echo "  db:"             >> docker-compose.override.yml
	@echo "    ports:"        >> docker-compose.override.yml
	@echo "      - 5432:5432" >> docker-compose.override.yml
	@echo "  web:"            >> docker-compose.override.yml
	@echo "    ports:"        >> docker-compose.override.yml
	@echo "      - 3000:3000" >> docker-compose.override.yml
ifeq ($(shell uname -s), Linux)
	@echo "    user: $(shell id -u):$(shell id -g)" >> docker-compose.override.yml
endif

#: Show information about the available targets
help:
	@$(SED) -En '/^#:.*/{ N; s/^#: (.*)\n([A-Za-z0-9_-]+).*/\2 \1/p }' $(MAKEFILE_LIST) \
		| sort \
		| while read label desc; do printf "\033[36m%-20s\033[0m %s\n" "$$label" "$$desc"; done
