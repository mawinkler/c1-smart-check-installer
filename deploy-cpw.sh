#!/bin/bash

set -e

printf '%s' "Get Cloud One Smart Check load balancer IP"

printf ' - %s\n' "${DSSC_HOST}"

if [ ! -f ~/pwchanged ];
then
  printf '%s' "Authenticate to Cloud One Smart Check"

  DSSC_TEMPPW='justatemppw'
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

printf '%s \n' "export DSSC_HOST=${DSSC_HOST}" > cloudOneCredentials.txt
printf '%s \n' "export DSSC_USERNAME=${DSSC_USERNAME}" >> cloudOneCredentials.txt
printf '%s \n' "export DSSC_PASSWORD=${DSSC_PASSWORD}" >> cloudOneCredentials.txt

printf '%s \n' "--------------"
printf '%s \n' "URL     : https://smartcheck-${DSSC_HOST//./-}.nip.io"
printf '%s \n' "User    : ${DSSC_USERNAME}"
printf '%s \n' "Password: ${DSSC_PASSWORD}"
