.PHONY: deploy build destroy

deploy:
	bash scripts/deploy.sh

build:
	bash scripts/build.sh

destroy:
	bash scripts/destroy.sh