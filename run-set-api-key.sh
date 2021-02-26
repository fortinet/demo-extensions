#!/bin/bash
#Runs the set-api-key and returns JSON as expected by terraform.
# We anticipate getting set-ap-key.sh.rendered.

value=`expect set-api-key.sh.rendered | grep 'New API key:' | awk 'NF>1{print $NF}' | tr -d '\r'`

echo "{\"token\":\"${value}\"}"