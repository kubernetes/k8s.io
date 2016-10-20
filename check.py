#!/usr/bin/env python
"""
Check status of domains from inventory.yaml
"""

from __future__ import print_function
import sys

import yaml
import requests

statusmap = {
    '200': 'OK',
    '404': 'Not Found',
    '302': 'Redirect',
}


inv = yaml.load(open('inventory.yaml'))
# calc names width for pretty printing
colwidth = max([len(item) for item in inv['domains']])+1


errors = 0

for site in inv['domains']:
    status = None
    message = ''
    try:
        resp = requests.head('http://' + site)
        status = str(resp.status_code)
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
            message = 'DNSLookupError'
        else:
            raise

    if status == None:
        errors += 1
    
    if not message:
        message = statusmap.get(status, '???')
        if status in ('404',):
            errors += 1

    print("{:{width}} {:5} {}".format(site, status, message, width=colwidth))

print('\n{} domains, {} errors'.format(len(inv['domains']), errors))
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
