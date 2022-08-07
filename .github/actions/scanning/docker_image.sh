#!/bin/bash
set -euo pipefail

if [[ -z "${1}" ]] || [[ -z "${1}" ]]; then
  echo "Usage: $0 DOCKER_IMAGE_NAME OUTPUT_PATH"
  exit 2
fi

grype_output_file="/tmp/grype_table.txt"
grype_disallowed_severities="High|Critical"

# Returns with the list of allowed CVEs.
get_cve_allowlist() {
  script_realpath=$(realpath "$0")
  script_dirname=$(dirname "${script_realpath}")

  # Global allow list
  allowlist=$(/tmp/yq r "${script_dirname}/cve_allowlist.yaml" '[].id' | tr "\n" "|")

  # Project/Repo specific allow list
  if [ -f "${GITHUB_WORKSPACE}/cve_allowlist.yaml" ]; then
    repo_allowlist=$(/tmp/yq r "${GITHUB_WORKSPACE}/cve_allowlist.yaml" '[].id' | tr "\n" "|")
    allowlist="${allowlist}${repo_allowlist}"
  fi

  returned_list=${allowlist::-1}

  echo "${returned_list}"
}

# Returns with number of CVEs.
# @param 1: the Grype tabular output file.
# @param 2: the list of NOT allowed severities, separated by pipe.
# @param 3: a list of allowed CVEs
filter_grype_table() {
  grype_output_file=${1}
  severity_to_fail_on=${2}
  allowlist=${3}
  error_count=$(grep -vE "${allowlist}" "${grype_output_file}" | grep -ciE "${severity_to_fail_on}")

  echo "${error_count}"
}

create_trivy_allowlist() {
  allowlist=$(get_cve_allowlist)
  allowlist=$(echo "${allowlist}" | tr "|" "\n")
  echo "${allowlist}" >"${GITHUB_WORKSPACE}/.trivyignore"
}

echo "Scanning ${1} image using Grype"
set +e
/tmp/grype/grype --fail-on "medium" --output "table" "${1}" >"${grype_output_file}"
set -e

# Lists the Grype output minus the allowed CVEs.
cve_allowlist=$(get_cve_allowlist)
grype_filter_error_count=$(filter_grype_table "${grype_output_file}" "${grype_disallowed_severities}" "${cve_allowlist}")
if [[ "${grype_filter_error_count}" != "0" ]]; then
  found_cves=$(grep -vE "${cve_allowlist}" "${grype_output_file}" | grep -iE "${grype_disallowed_severities}")
  echo "CVEs detected."
  echo "${found_cves}"
else
  echo "No CVEs found after filtering allowed CVEs."
fi

echo "Scanning ${1} image using Trivy"
create_trivy_allowlist
/tmp/trivy/trivy image --timeout 5m0s --exit-code 0 --severity UNKNOWN,LOW,MEDIUM "${1}"

echo "CVE Exceptions: "
cd "${GITHUB_WORKSPACE}"
cat .trivyignore
set +e
/tmp/trivy/trivy image --timeout 5m0s --exit-code 21 --severity HIGH,CRITICAL "${1}"
trivy_exit_code=$?
set -e

echo "Compiling a list of assets for image ${1} using Syft"
set +e
/tmp/syft/syft -o table "${1}"
mkdir -p "${2}/${1}"
SYFT_OUTPUT_PATH="${2}/${1}/syft.json"
echo "Outputting Syft findings to ${SYFT_OUTPUT_PATH}"
/tmp/syft/syft -o json "${1}" >"${SYFT_OUTPUT_PATH}"
set -e

if [[ "${grype_filter_error_count}" != "0" ]]; then
  echo "Vulnerability threshold set for Grype has not passed. See the Grype output for details."
  exit 143
fi

if [[ "${trivy_exit_code}" != "0" ]]; then
  echo "Trivy has found some vulnerabilities in ${1} image"
  exit 144
fi
