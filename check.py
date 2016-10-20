#!/usr/bin/env python
"""
Check status of domains from inventory.yaml
"""

from __future__ import print_function
import sys

import yaml
import requests

inv = yaml.load(open('inventory.yaml'))


errors = 0

for site in inv['domains']:
    try:
        status = requests.head('http://' + site)
    except requests.ConnectionError as exc:
        # filtering DNS lookup error from other connection errors
        # (until https://github.com/shazow/urllib3/issues/1003 is resolved)
        if type(exc.message) != requests.packages.urllib3.exceptions.MaxRetryError:
            raise
        reason = exc.message.reason    
        if type(reason) != requests.packages.urllib3.exceptions.NewConnectionError:
            raise
        if type(reason.message) != str:
            raise
        if ("[Errno 11001] getaddrinfo failed" in reason.message or     # Windows
            "[Errno -2] Name or service not known" in reason.message):  # Linux
            status = 'DNSLookupError'
        else:
            raise

    if status == 'DNSLookupError':
        errors += 1
    elif status.status_code in (404,):
        errors += 1
    print(site, status)

if errors:
    print('Total errors: %s' % errors)
sys.exit(errors)

"""

* [x] catch missing/expired DNS records
  * [ ] generate signal (fedmsg?)
* [ ] follow redirects
  * [ ] show redirects
  * [ ] configure redirects from inventory.yaml
* [ ] check https availability
  * [ ] check http and https content matches (or redirects)
* [x] return error code

"""
