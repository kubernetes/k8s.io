#!/usr/bin/env python
'''
Octo-DNS Reporter / exit non-zero on failure
'''

from __future__ import absolute_import, division, print_function, \
    unicode_literals

from concurrent.futures import ThreadPoolExecutor
from dns.exception import Timeout
from dns.resolver import NXDOMAIN, NoAnswer, NoNameservers, Resolver, query
from logging import getLogger
from sys import stdout,exit
import re

from octodns.cmds.args import ArgumentParser
from octodns.manager import Manager
from octodns.zone import Zone


class AsyncResolver(Resolver):

    def __init__(self, num_workers, *args, **kwargs):
        super(AsyncResolver, self).__init__(*args, **kwargs)
        self.executor = ThreadPoolExecutor(max_workers=num_workers)

    def query(self, *args, **kwargs):
        return self.executor.submit(super(AsyncResolver, self).query, *args,
                                    **kwargs)


def main():
    parser = ArgumentParser(description=__doc__.split('\n')[1])

    parser.add_argument('--config-file', required=True,
                        help='The Manager configuration file to use')
    parser.add_argument('--zone', required=True, help='Zone to dump')
    parser.add_argument('--source', required=True, default=[], action='append',
                        help='Source(s) to pull data from')
    parser.add_argument('--num-workers', default=4,
                        help='Number of background workers')
    parser.add_argument('--timeout', default=8,
                        help='Number seconds to wait for an answer')
    parser.add_argument('server', nargs='+', help='Servers to query')

    args = parser.parse_args()

    manager = Manager(args.config_file)

    log = getLogger('report')

    try:
        sources = [manager.providers[source] for source in args.source]
    except KeyError as e:
        raise Exception('Unknown source: {}'.format(e.args[0]))

    zone = Zone(args.zone, manager.configured_sub_zones(args.zone))
    for source in sources:
        source.populate(zone)

    print('name,type,ttl,{},consistent'.format(','.join(args.server)))
    resolvers = []
    ip_addr_re = re.compile(r'^[\d\.]+$')
    for server in args.server:
        resolver = AsyncResolver(configure=False,
                                 num_workers=int(args.num_workers))
        if not ip_addr_re.match(server):
            server = unicode(query(server, 'A')[0])
        log.info('server=%s', server)
        resolver.nameservers = [server]
        resolver.lifetime = int(args.timeout)
        resolvers.append(resolver)

    queries = {}
    for record in sorted(zone.records):
        queries[record] = [r.query(record.fqdn, record._type)
                           for r in resolvers]
    dns_error = False

    for record, futures in sorted(queries.items(), key=lambda d: d[0]):
        stdout.write(record.fqdn)
        stdout.write(',')
        stdout.write(record._type)
        stdout.write(',')
        stdout.write(unicode(record.ttl))
        compare = {}
        for future in futures:
            stdout.write(',')
            try:
                raw_answers = future.result()
                answers = [unicode(r).replace('"','') for r in raw_answers]
            except NXDOMAIN:
                answers = ['*does not exist*']
                dns_error = True
            except Timeout:
                answers = ['*timeout*']
                dns_error = True
            except (NoAnswer, NoNameservers):
                # unsure why NS records come back: *** NoAnswer:
                # The DNS response does not contain an answer to the question: X. IN NS
                # However all other records wo can compare
                if record._type == 'NS':
                    continue
                answers = ['*no answer*']
                dns_error = True
            stdout.write(' '.join(answers))
            #depending on the type, let's get a list of all values
            if hasattr(record,'values'):
                values = record.values
            else:
                values = [record.value]
            for value in values:
                value = unicode(value).replace("'","")
                if value in answers:
                    continue
                dns_error = True
                # stdout.write(unicode(value))
                # import ipdb; ipdb.set_trace()
                # if record._type == 'MX':
                #     import ipdb; ipdb.set_trace()

            # sorting to ignore order
            answers = '*:*'.join(sorted(answers)).lower()
            compare[answers] = True
        stdout.write(',True\n' if len(compare) == 1 else ',False\n')

    if dns_error:
        exit(1)
    else:
        exit(0)

if __name__ == '__main__':
    main()
