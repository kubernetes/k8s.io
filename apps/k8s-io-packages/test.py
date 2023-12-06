#!/usr/bin/env python3

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

try:
    import HTMLParser
    import httplib
    import urlparse
except ImportError:
    import html.parser as HTMLParser
    import http.client as httplib
    import urllib.parse as urlparse
import os
import random
import socket
import ssl
import subprocess
import unittest
import urllib.request

import yaml

SSL_VERIFY_DISABLE = False

def rand_num():
    return random.randint(1000, 10000)


def do_get(url):
    parsed = urlparse.urlparse(url)
    path = parsed.path
    if parsed.query:
        path = '%s?%s' % (path, parsed.query)
    if parsed.scheme == 'http':
        conn = httplib.HTTPConnection(TARGET_IP)
    elif parsed.scheme == 'https':
        # We can't use plain old httplib.HTTPSConnection as we are connecting
        # via IP address but need to verify the certificate chain based on the
        # host name. HTTPSConnection isn't smart enough to pull out the host
        # header. Instead we manually TLS wrap the socket for a HTTPConnection
        # and override the hostname to verify.
        conn = httplib.HTTPConnection(TARGET_IP, 443)
        context = ssl.create_default_context()
        if SSL_VERIFY_DISABLE:
            context = ssl._create_unverified_context()
        conn.connect()
        conn.sock = context.wrap_socket(
            conn.sock, server_hostname=parsed.netloc)
    conn.request('GET', path, headers={'Host': parsed.netloc})
    resp = conn.getresponse()
    body = resp.read().decode('utf8')
    resp.close()
    conn.close()
    return resp, body


class HTTPTestCase(unittest.TestCase):
    def do_get(self, url, expected_code):
        resp, body = do_get(url)
        self.assertEqual(resp.status, expected_code,
                '\nGET "%s" got an unexpected status code:\n want: %d\n got:  %d'
                % (url, expected_code, resp.status))
        return resp, body

    def assert_code(self, url, expected_code):
        print('GET: %s => %s' % (url, expected_code))
        return self.do_get(url, expected_code)

class RedirTest(HTTPTestCase):
    def assert_scheme_redirect(self, url, expected_loc, expected_code, **kwargs):
        for k, v in kwargs.items():
            k = '$%s' % k
            v = '%s' % v
            url = url.replace(k, v)
            expected_loc = expected_loc.replace(k, v)
        print('REDIR: %s => %s' % (url, expected_loc))
        resp, body = self.do_get(url, expected_code)
        self.assertEqual(resp.getheader('location'), expected_loc,
                '\nGET "%s" got an unexpected redirect location:\n want: %s\n got:  %s'
                % (url, expected_loc, resp.getheader('location')))

    def assert_multischeme_redirect(self, partial_url, expected_loc, expected_code, **kwargs):
        for scheme in ('http', 'https'):
            self.assert_scheme_redirect(
                    scheme + '://' + partial_url, expected_loc, expected_code, **kwargs)

    def assert_temp_redirect(self, partial_url, expected_loc, **kwargs):
        self.assert_multischeme_redirect(partial_url, expected_loc, 302, **kwargs)

    def assert_permanent_redirect(self, partial_url, expected_loc, **kwargs):
        self.assert_multischeme_redirect(partial_url, expected_loc, 301, **kwargs)

    def test_yum(self):
        for base in ('yum.k8s.io', 'yum.kubernetes.io'):
            self.assert_temp_redirect(base, 'https://packages.cloud.google.com/yum/')
            self.assert_temp_redirect(base + '/$id',
                'https://packages.cloud.google.com/yum/$id', id=rand_num())

    def test_apt(self):
        for base in ('apt.k8s.io', 'apt.kubernetes.io'):
            self.assert_temp_redirect(base, 'https://packages.cloud.google.com/apt/')
            self.assert_temp_redirect(base + '/$id',
                'https://packages.cloud.google.com/apt/$id', id=rand_num())

class GoMetaParser(HTMLParser.HTMLParser, object):
    def __init__(self):
        super(GoMetaParser, self).__init__()
        self.__go_meta_tags = dict()

    def handle_starttag(self, tag, attrs):
        if tag != "meta":
            return

        attrs = dict(attrs)
        if attrs['name'] not in ('go-import', 'go-source'):
            return

        if 'content' not in attrs:
            return

        # remove extraneous whitespace from content value
        content = ' '.join(attrs['content'].split())

        self.__go_meta_tags[attrs['name']] = content

    def go_meta_tag(self, name):
        return self.__go_meta_tags.get(name)


if __name__ == '__main__':
    TARGET_IP = os.environ.get('TARGET_IP')
    if not TARGET_IP:
        print('Attempting to autodiscover service TARGET_IP, set env var to override...')
        TARGET_IP = socket.gethostbyname('apt.k8s.io')
        print('Testing against service at', TARGET_IP)
    else:
        print('TARGET_IP present in environment. Disabling SSL verification')
        SSL_VERIFY_DISABLE = True
    unittest.main()
