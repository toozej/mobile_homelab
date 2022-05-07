# Makefile to generate all necessary certificates and keys for SSL communication using Docker-ized cfssl tool
# based on https://github.com/etcd-io/etcd/tree/master/hack/tls-setup

.PHONY: ca whoami clean

CFSSL	= docker run --rm --name cfssl --workdir=/app -v $(CURDIR):/app cfssl/cfssl:latest
JSON	= docker run --rm --name cfssljson --workdir=/app --entrypoint=cfssljson -v $(CURDIR):/app cfssl/cfssl:latest

all: ca whoami

ca:
	# create CA key and cert as a temporary JSON file
	$(CFSSL) gencert -initca ca/ca-csr.json > ca/ca-cert.json
	# convert the CA key and cert JSON file into separate PEM files
	$(JSON) -bare -f ca/ca-cert.json ./ca/ca
	# trash the temporary JSON file
	rm ca/ca-cert.json

whoami:
	# generate webUI whoami cert
	$(CFSSL) gencert \
	  -ca ca/ca.pem \
	  -ca-key ca/ca-key.pem \
	  -config ca/ca-config.json \
	  whoami/whoami-csr.json > whoami/whoami-cert.json
	$(JSON) -bare -f whoami/whoami-cert.json whoami/whoami
	# whoami fails to start due to not having permissions to load key, must set its permissions to readable
	sudo chmod 0755 whoami/whoami-key.pem
	cat whoami/whoami.pem whoami/whoami-key.pem > whoami/whoami-combined.pem
	cat whoami/whoami.pem ca/ca.pem > whoami/whoami-ca-combined.pem
	cat whoami/whoami-combined.pem > haproxy/combined.pem
	rm whoami/whoami-cert.json

clean:
	rm -rf ca/*.pem ca/*.csr whoami/*.pem whoami/*.csr
