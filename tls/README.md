# SSL Configuration for Sensu Go

As easy as `make`

## CA
`make ca`

## ETCD
`make etcd`
Based heavily off example: https://github.com/etcd-io/etcd/tree/master/hack/tls-setup

## API
`make api`

## Dashboard
`make dashboard`
Note this only creates one certificate/key pair, rather than the ETCD and API directives which make one certificate/key pair per Sensu Go backend node

## Agent
`make agent`
