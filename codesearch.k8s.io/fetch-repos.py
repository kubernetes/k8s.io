import requests
import json

url = 'https://api.github.com/orgs/kubernetes/repos?per_page=200'

resp = requests.get(url=url)
data = resp.json()

config = {
    "max-concurrent-indexers": 2,
    "dbpath": "data",
    "repos": {}
}

for repo in data:
    name = repo['full_name'].split('/')[1]
    config["repos"][name] = {
        "url": "https://github.com/kubernetes/%s.git" % name,
        "ms-between-poll": 360000
    }

print(json.dumps(config, indent=4))
