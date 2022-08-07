#!/bin/bash

yq_version="3.4.1"

set -e
echo "Installing yq"
curl -sL https://github.com/mikefarah/yq/releases/download/${yq_version}/yq_linux_amd64 -o /tmp/yq && chmod +x /tmp/yq
echo "Installing Syft"
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /tmp/syft
echo "Installing Grype"
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /tmp/grype
echo "Installing Trivy"
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/master/contrib/install.sh | sh -s -- -b /tmp/trivy

sudo apt-get update
sudo apt-get install -y clamav
sudo systemctl stop clamav-freshclam
sudo freshclam
