#!/usr/bin/env python

from datetime import datetime
import os

created = datetime.now().strftime('%Y-%m-%dT%H:%M:%SZ')
registry_name = os.getenv("ECR_SERVER_HOST")
image_name = os.getenv("IMAGE_NAME") if os.getenv("IMAGE_NAME") else os.getenv("GITHUB_REPOSITORY").split("/")[1].replace("img-", "")
repo_image_name = image_name
repo_sha = os.getenv("GITHUB_SHA")

print("ECR_SERVER_HOST=%s" % (registry_name))
print("CREATED=%s" % (created))
print("IMAGE_NAME=%s" % (repo_image_name))
print("IMAGE_TAG=%s" % (repo_sha))
print("IMAGE_NAME_FULL=%s/%s:%s" % (registry_name, repo_image_name, repo_sha))

if os.path.isfile("docker_images"):
    with open("docker_images") as file:
        image_names = file.read().replace('\n', ',').strip(" ,")
        print("IMAGE_NAMES=%s" % (image_names))
