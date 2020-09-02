#!/usr/bin/env bash

##
# kubernetes-cli-log-searcher
# 
# Searches all kubernetes logs in a namespace based on a 'pod_name_filter' and a 'search_filter'
# and dumps the hits with with some context (based on lines_before and lines_after) in a file 
# called 'log_extract.txt'
##

lines_before="50"
lines_after="50"

function clean {
    rm -rf "${tmp_directory}"
}
trap clean EXIT

function help() {
        cat << EOF
Usage: 
  ${0} -p <pod_name_filter> -s <search_filter> [-b <lines_before> -a <lines_after>]

Defaults:
  lines_before: 50
  lines_after: 50
EOF

  exit 1
}

function error_out_on() {
    echo "[ERROR] ${*}"
    exit 1
}

while getopts 'p:c:s:b:a:h' flag; do
  case "${flag}" in
    p) pod_name_filter="${OPTARG}" ;;
    s) search_filter="${OPTARG}" ;;
    b) lines_before="${OPTARG}" ;;
    a) lines_after="${OPTARG}" ;;
    h) help ;;
    *) help
       exit 1 ;;
  esac
done

if [[ -z ${pod_name_filter} ]]; then
    error_out_on "Pod name filter not provided"
fi

if [[ -z ${search_filter} ]]; then
    error_out_on "Search filter not provided"
fi

tmp_directory=$(mktemp -d) || error_out_on "Unable to create a temporary directory"

pods=$(kubectl get pods | grep -i "${pod_name_filter}" | awk '{ print $1 }')

for pod in ${pods}; do
    kubectl logs "${pod}" --all-containers=true --timestamps=true --prefix=true > "${tmp_directory}/${pod}.log"
done

echo "Found the following number of hits on search query '${search_filter}':"
grep -R --count --ignore-case "${search_filter}" "${tmp_directory}" | sed "s&${tmp_directory}/&&" | sed 's&.log&&'

grep -R --ignore-case "${search_filter}" --no-filename --after-context "${lines_after}" --before-context "${lines_before}" "${tmp_directory}" > ./log_extract.txt
echo "All hits can be found in './log_extract.txt'"