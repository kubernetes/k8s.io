#!/usr/bin/env python
'''
Octo-DNS Reporter / exit non-zero on failure
'''

from __future__ import absolute_import, division, print_function, \
    unicode_literals

from concurrent.futures import ThreadPoolExecutor
from logging import getLogger
from sys import stdout
import sys
from dns.exception import Timeout
from dns.resolver import NXDOMAIN, NoAnswer, NoNameservers, Resolver, query
import re

from octodns.cmds.args import ArgumentParser
from octodns.manager import Manager
from octodns.zone import Zone


class AsyncResolver(Resolver):
    """
    Create an DNS resolver using an async pool of workers
    """

    def __init__(self, num_workers, *args, **kwargs):
        super(AsyncResolver, self).__init__(*args, **kwargs)
        self.executor = ThreadPoolExecutor(max_workers=num_workers)

    def query(self, *args, **kwargs):
        return self.executor.submit(super(AsyncResolver, self).query, *args,
                                    **kwargs)


def main():
    """check-zone based on octodns config file and dns zone
    Will query all 4 DNS servers configured for the zone in GCP.
    """
    parser = ArgumentParser(description=__doc__.split('\n')[1])

    parser.add_argument('--config-file', required=True,
                        help='The OctoDNS configuration file to use')
    parser.add_argument('--zone', required=True, help='zone to check')

    args = parser.parse_args()
    log = getLogger('report')

    manager = Manager(args.config_file)
    zone = Zone(args.zone, manager.configured_sub_zones(args.zone))
    gcp = manager.providers['gcp']
    project = gcp.gcloud_client.project
    gcp.populate(zone)
    #import ipdb ; ipdb.set_trace()

    # Retrieve the DNS Servers directly from the GCP configuration
    dns_servers = gcp.gcloud_zones[args.zone].name_servers
    print('Using GCP project {}'.format(project))
    print('name,type,ttl,{},consistent'.format(','.join(dns_servers)))

    # Configure Resolvers (one per DNS server)
    resolvers = []
    ip_addr_re = re.compile(r'^[\d\.]+$')
    for server in dns_servers:
        resolver = AsyncResolver(configure=False,
                                 num_workers=4)
        # We need to resolve this if it's not an IP
        if not ip_addr_re.match(server):
            server = unicode(query(server, 'A')[0])
        log.info('server=%s', server)
        resolver.nameservers = [server]
        resolver.lifetime = 8
        resolvers.append(resolver)

    # Populate the queries to make based on zone configuration
    queries = {}
    for record in sorted(zone.records):
        queries[record] = [r.query(record.fqdn, record._type)
                           for r in resolvers]
    # No dns_error unless we find one
    dns_error = False

    # Resolve records looking for errors
    for record, responses in sorted(queries.items(), key=lambda d: d[0]):
        # Print out a log each record
        stdout.write(record.fqdn)
        stdout.write(',')
        stdout.write(record._type)
        stdout.write(',')
        stdout.write(unicode(record.ttl))
        results = {}
        for response in responses:
            stdout.write(',')
            try:
                raw_answers = response.result()
                answers = [unicode(r).replace('"','') for r in raw_answers]
            except NXDOMAIN:
                answers = ['*does not exist*']
                dns_error = True
            except Timeout:
                answers = ['*timeout*']
                dns_error = True
            except (NoAnswer, NoNameservers):
                # FIXME: unsure why NS records come back: *** NoAnswer:
                # The DNS response does not contain an answer to the question: X. IN NS
                # However all other records we can compare
                if record._type == 'NS':
                    continue
                answers = ['*no answer*']
                dns_error = True
            stdout.write(' '.join(answers))

            # Get a list of configured_values
            # (even for ones that only have one value)
            if hasattr(record,'values'):
                configured_values = record.values
            else:
                configured_values = [record.value]

            # All configured_values should be included in the response
            # otherwise, we have a dns_error
            for value in configured_values:
                value = unicode(value).replace("'","")
                if value in answers:
                    continue
                dns_error = True

            # sorting answers to ignore order, before adding to results
            # This let's us ensure that all DNS servers responded the same
            answers = '*:*'.join(sorted(answers)).lower()
            results[answers] = True

        # All responses should be the same... across all nameservers
        stdout.write(',True\n' if len(results) == 1 else ',False\n')

    if dns_error:
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == '__main__':
    main()
