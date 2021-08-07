#!make

-include .env

TODAY ?= $(shell date +"%Y-%m-%d")
GCC ?= /bin/bash
GCMD ?=  ./ubuntu-autoinstall-generator.sh
GCFLAGS ?= --all-in-one
USER_DATA_INFILE ?= ./user-data.template.yaml
USER_DATA_FILE ?= ./user-data.yaml

PROJECT := simple
PASSWORD ?= ubuntu
INSTALL_SSH_SERVER ?= false
PUB_KEY ?= $(shell cat id_rsa.pub)
ENCRYPTED_PASSWORD ?= $(shell /usr/bin/openssl passwd -1 $(PASSWORD))

RANDOM_ADJ := $(shell cat /usr/share/dict/words \
    | grep -E '^[[:alpha:]]{1,5}$$' \
	| grep -e 'ly$$' -e 'ing$$' -e 'ed$$'\
	| sed -e 's/\(.*\)/\L\1/'| shuf -n1)

RANDOM_WORD := $(shell cat /usr/share/dict/words \
    | grep -E '^[[:alpha:]]{1,5}$$' \
	| shuf -n1 \
	| sed -e s/"'s"/""/g \
	| sed -e 's/\(.*\)/\L\1/' \
	| sed -e 's/ *$$//g')

HOSTNAME ?= $(RANDOM_ADJ)-$(RANDOM_WORD)
USERNAME ?= ubuntu
ISO_OUTFILE ?= $(HOSTNAME)_$(TODAY).iso

ENV_CONTENTS := $(shell cat ./.env)

MAKE_ENV += ENCRYPTED_PASSWORD
MAKE_ENV += PUB_KEY
MAKE_ENV += HOSTNAME
MAKE_ENV += USERNAME
MAKE_ENV += INSTALL_SSH_SERVER

SHELL_EXPORT := $(foreach v,$(MAKE_ENV),$(v)='$($(v))' )

CDROM ?= $(shell find . -maxdepth 1 -type f -iname "*_$(TODAY).iso" | head -1)
RELEASE ?= 20.04
INSTALLER := /usr/bin/virt-install
URI ?= qemu:///system

RAM ?= 2096
DISK ?= pool=default,size=25,bus=virtio,format=qcow2
VCPUS ?= 1
OS_TYPE := linux
OS_VARIANT := ubuntu$(RELEASE)
NETWORK ?= network:default
GRAPHICS ?= vnc
CONSOLE ?= pty,target_type=serial
VM_NAME ?= $(HOSTNAME)

compile:
	$(MAKE) get_pub_key
ifneq (,$(findstring HOSTNAME,$(ENV_CONTENTS)))
    # Found
else
	echo "\nHOSTNAME=$(HOSTNAME)" >> ./.env;
endif
	$(SHELL_EXPORT) envsubst <$(USER_DATA_INFILE) >$(USER_DATA_FILE); \
	$(GCC) $(GCMD) $(GCFLAGS) --user-data $(USER_DATA_FILE) --destination $(ISO_OUTFILE)

encrypt_password:
	@/usr/bin/openssl passwd -1 $(PASSWORD)

create_keypair:
	ssh-keygen -t rsa -b 4096 -f id_rsa -C $(PROJECT) -N "" -q
	chmod 600 id_rsa

write_file:
	$(SHELL_EXPORT) envsubst <$(USER_DATA_INFILE) >$(USER_DATA_FILE)

get_pub_key:
ifeq ($(PUB_KEY),)
	$(MAKE) create_keypair
endif

build_user_data:
	$(MAKE) get_pub_key
	$(MAKE) write_file

remove_old_keys:
	rm ./*id_rsa*
	rm ./*SHA256SUMS*
	rm ./*.keyring

cleanup_isos:
	rm -f ./*.iso

make_clean_all:
	$(MAKE) remove_old_keys
	$(MAKE) cleanup_isos

install:
	$(INSTALLER) \
	    --connect=$(URI) \
	    --name $(VM_NAME) \
	    --ram $(RAM) \
	    --disk $(DISK) \
	    --vcpus $(VCPUS) \
	    --os-type $(OS_TYPE) \
	    --os-variant $(OS_VARIANT) \
	    --network $(NETWORK) \
	    --graphics $(GRAPHICS) \
	    --console $(CONSOLE) \
	    --cdrom $(CDROM) \
	    --force --debug

all:
	$(MAKE) compile
	$(MAKE) install
