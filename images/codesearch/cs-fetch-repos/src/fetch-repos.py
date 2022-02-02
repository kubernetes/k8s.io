#!/usr/bin/env python

# Copyright 2021 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Updates the repo list of the codesearch app 

import requests
import json
import os
import sys

REPOS = [
    'kubernetes',
    'kubernetes-client',
    'kubernetes-csi',
    'kubernetes-incubator',
    'kubernetes-sigs',
]

CONFIG = {
    "max-concurrent-indexers": 10,
    "dbpath": "data",
    "vcs-config": {
        "git": {
            "detect-ref" : True,            
            "ref" : "main"
        }
    },
    "repos": {}
}

def fetch_repos():
    print("Starting Fetch Repo Script..")

    file_path = "/data/config.json"
    if os.environ.get('CONFIG_PATH') is not None:
        file_path = os.environ.get('CONFIG_PATH')

    for repo in REPOS:
        page = 0
        while True:
            page += 1
            resp = requests.get(url= "https://api.github.com/orgs/" + repo + "/repos?per_page=100&page=" + str(page))
            data = resp.json()
            if len(data) == 0:
                break
            if 'message' in data:
                print(data["message"], file=sys.stderr)
                sys.exit(1)
                break
            for item in data:
                name = item['full_name'].split('/')[1]
                CONFIG["repos"][repo + "/" + name] = {
                    "url": "https://github.com/%s/%s.git" % (repo, name),
                    "ms-between-poll": 360000
                }

        with open(file_path, 'w') as f:
            f.write(json.dumps(CONFIG, indent=4, sort_keys=True))
        print("File config saved to: %s" % file_path)

if __name__ == "__main__":
    fetch_repos()