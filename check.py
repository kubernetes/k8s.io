#!/usr/bin/env python

from __future__ import print_function

import yaml
import requests

inv = yaml.load(open('inventory.yaml'))

for site in inv['domains']:
    status = requests.head('http://' + site)
    print(site, status)
