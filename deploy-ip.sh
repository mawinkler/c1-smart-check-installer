#!/bin/bash

set -e

printf '%s' "Configure Cloud One Smart Check namespace"

kubectl create namespace ${DSSC_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - > /dev/null

printf ' - %s\n' "configured"

printf '%s' "Configure Smart Check overrides"

DSSC_TEMPPW='justatemppw'
cat <<EOF >./overrides-image-security.yml
##
## Default value: (none)
activationCode: '${DSSC_AC}'
auth:
  ## secretSeed is used as part of the password generation process for
  ## all auto-generated internal passwords, ensuring that each installation of
  ## Deep Security Smart Check has different passwords.
  ##
  ## Default value: {must be provided by the installer}
  secretSeed: 'just_anything-really_anything'
  ## userName is the name of the default administrator user that the system creates on startup.
  ## If a user with this name already exists, no action will be taken.
  ##
  ## Default value: administrator
  ## userName: administrator
  userName: '${DSSC_USERNAME}'
  ## password is the password assigned to the default administrator that the system creates on startup.
  ## If a user with the name 'auth.userName' already exists, no action will be taken.
  ##
  ## Default value: a generated password derived from the secretSeed and system details
  ## password: # autogenerated
  password: '${DSSC_TEMPPW}'
EOF

cat <<EOF >./overrides-image-security-upgrade.yml
registry:
  ## Enable the built-in registry for pre-registry scanning.
  ##
  ## Default value: false
  enabled: true
    ## Authentication for the built-in registry
  auth:
    ## User name for authentication to the registry
    ##
    ## Default value: empty string
    username: '${DSSC_REGUSER}'
    ## Password for authentication to the registry
    ##
    ## Default value: empty string
    password: '${DSSC_REGPASSWORD}'
    ## The amount of space to request for the registry data volume
    ##
    ## Default value: 5Gi
  dataVolume:
    sizeLimit: 10Gi
certificate:
  secret:
    name: k8s-certificate
    certificate: tls.crt
    privateKey: tls.key
EOF

printf ' - %s\n' "configured"

if [ "$(helm --namespace ${DSSC_NAMESPACE} list -q | grep deep)" != "" ] ;
  then
    printf '%s' "Upgrading Cloud One Smart Check"
    helm upgrade --namespace ${DSSC_NAMESPACE} \
      --values overrides-image-security.yml \
      deepsecurity-smartcheck \
      https://github.com/deep-security/smartcheck-helm/archive/master.tar.gz \
      --reuse-values > /dev/null
    printf ' - %s\n' "upgraded"
  else
    printf '%s' "Installing Cloud One Smart Check"
    helm install --namespace ${DSSC_NAMESPACE} \
      --values overrides-image-security.yml \
      deepsecurity-smartcheck \
      https://github.com/deep-security/smartcheck-helm/archive/master.tar.gz > /dev/null
    printf ' - %s\n' "installed"
fi

printf '%s' "Waiting for Cloud One Smart Check to be in active state"

SMARTCHECK_DEPLOYMENTS=$(kubectl -n smartcheck get deployments | grep -c "/")

while [ $(kubectl -n smartcheck get deployments | grep -cE "1/1|2/2") -ne ${SMARTCHECK_DEPLOYMENTS} ]
do
  printf '%s' "."
  sleep 2
done

printf ' - %s\n' "active"

printf '%s' "Get Cloud One Smart Check load balancer IP"

DSSC_HOST=''
while [ "$DSSC_HOST" == '' ]
do
  DSSC_HOST=$(kubectl get svc -n ${DSSC_NAMESPACE} proxy \
              -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  printf '%s' "."
  sleep 2
done

printf ' - %s\n' "${DSSC_HOST}"

if [ ! -f ~/pwchanged ];
then
  printf '%s' "Authenticate to Cloud One Smart Check"

  DSSC_BEARERTOKEN=''
  while [ "$DSSC_BEARERTOKEN" == '' ]
  do
    DSSC_USERID=`curl -s -k -X POST https://${DSSC_HOST}/api/sessions \
                    -H "Content-Type: application/json" \
                    -H "Api-Version: 2018-05-01" \
                    -H "cache-control: no-cache" \
                    -d "{\"user\":{\"userid\":\"${DSSC_USERNAME}\",\"password\":\"${DSSC_TEMPPW}\"}}" | \
                      jq '.user.id' | tr -d '"'  2>/dev/null`
    DSSC_BEARERTOKEN=`curl -s -k -X POST https://${DSSC_HOST}/api/sessions \
                    -H "Content-Type: application/json" \
                    -H "Api-Version: 2018-05-01" \
                    -H "cache-control: no-cache" \
                    -d "{\"user\":{\"userid\":\"${DSSC_USERNAME}\",\"password\":\"${DSSC_TEMPPW}\"}}" | \
                      jq '.token' | tr -d '"'  2>/dev/null`
    printf '%s' "."
    sleep 2
  done

  printf ' - %s\n' "authenticated"

  printf '%s' "Executing initial password change"

  DUMMY=`curl -s -k -X POST https://${DSSC_HOST}/api/users/${DSSC_USERID}/password \
          -H "Content-Type: application/json" \
          -H "Api-Version: 2018-05-01" \
          -H "cache-control: no-cache" \
          -H "authorization: Bearer ${DSSC_BEARERTOKEN}" \
          -d "{  \"oldPassword\": \"${DSSC_TEMPPW}\", \"newPassword\": \"${DSSC_PASSWORD}\"  }"`

  printf ' - %s\n' "done"
  touch ~/pwchanged
fi

printf '%s' "Configure Smart Check certificate"

cat <<EOF >./req.conf
[req]
  distinguished_name=req
[san]
  subjectAltName=DNS:smartcheck-${DSSC_HOST//./-}.nip.io
EOF

openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
  -keyout k8s.key -out k8s.crt \
  -subj "/CN=smartcheck-${DSSC_HOST//./-}.nip.io" -extensions san -config req.conf &> /dev/null
kubectl create secret tls k8s-certificate --cert=k8s.crt --key=k8s.key \
  --dry-run=true -n ${DSSC_NAMESPACE} -o yaml | kubectl apply -f - > /dev/null

printf ' - %s\n' "done"

printf '%s' "Upgrading Cloud One Smart Check"

helm upgrade --namespace ${DSSC_NAMESPACE} \
  --values overrides-image-security-upgrade.yml \
  deepsecurity-smartcheck \
  https://github.com/deep-security/smartcheck-helm/archive/master.tar.gz \
  --reuse-values > /dev/null

printf ' - %s\n' "upgraded"

printf '%s \n' "--------------"
printf '%s \n' "URL     : https://smartcheck-${DSSC_HOST//./-}.nip.io"
printf '%s \n' "User    : ${DSSC_USERNAME}"
printf '%s \n' "Password: ${DSSC_PASSWORD}"
