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

    def test_main_urls(self):
        # Main redirects, HTTPS to avoid protocol upgrade redirect.
        path = '/%s' % rand_num()
        self.assert_scheme_redirect(
                'https://k8s.io',
                'https://kubernetes.io/', 301)
        self.assert_scheme_redirect(
                'https://k8s.io/',
                'https://kubernetes.io/', 301)
        self.assert_scheme_redirect(
                'https://k8s.io/' + path,
                'https://kubernetes.io/' + path, 301)

    def test_sig_urls(self):
        for base in ('https://sigs.k8s.io', 'https://sigs.kubernetes.io'):
            self.assert_scheme_redirect(
                    base,
                    'https://github.com/kubernetes-sigs/',
                    301)
            self.assert_scheme_redirect(
                    base + '/$sig_repo',
                    'https://github.com/kubernetes-sigs/$sig_repo',
                    301,
                    sig_repo=rand_num())
            self.assert_scheme_redirect(
                    base + '/$sig_repo/',
                    'https://github.com/kubernetes-sigs/$sig_repo/',
                    301,
                    sig_repo=rand_num())
            self.assert_scheme_redirect(
                    base + '/$sig_repo/$repo_subpath',
                    'https://github.com/kubernetes-sigs/$sig_repo/blob/master/$repo_subpath',
                    301,
                    sig_repo=rand_num(), repo_subpath=rand_num())

    def test_protocol_upgrade(self):
        for url in ('kubernetes.io', 'k8s.io', 'sigs.k8s.io', 'sigs.kubernetes.io'):
            self.assert_scheme_redirect(
                    'http://' + url,
                    'https://' + url + '/', 301)
            self.assert_scheme_redirect(
                    'http://' + url + '/',
                    'https://' + url + '/', 301)

        path = '/%s' % rand_num()
        for url in ('kubernetes.io', 'k8s.io', 'sigs.k8s.io', 'sigs.kubernetes.io'):
            self.assert_scheme_redirect(
                    'http://' + url + path,
                    'https://' + url + path, 301)

    def test_go_get(self):
        self.assert_scheme_redirect(
                'http://k8s.io/kubernetes?go-get=1',
                'https://k8s.io/kubernetes?go-get=1', 301)
        self.assert_code('https://k8s.io/kubernetes?go-get=1', 200)

        # automatic redirects that aren't hard-coded
        for url in ('sigs.k8s.io',):
            self.assert_scheme_redirect(
                'http://' + url + '/example-test-repo?go-get=1',
                'https://' + url + '/example-test-repo?go-get=1', 301)
            self.assert_code('https://' + url + '/example-test-repo?go-get=1', 200)

    def test_healthz(self):
        self.assert_code('http://k8s.io/_healthz', 200)
        self.assert_code('https://k8s.io/_healthz', 200)

    def test_go(self):
        for base in ('go.k8s.io/', 'go.kubernetes.io/'):
            self.assert_temp_redirect(base + 'bot-commands',
                'https://prow.k8s.io/command-help')
            self.assert_temp_redirect(base + 'github-labels',
                'https://github.com/kubernetes/test-infra/blob/master/label_sync/labels.md')
            self.assert_temp_redirect(base + 'good-first-issue',
                'https://github.com/search?q=org%3Akubernetes+org%3Akubernetes-sigs+org%3Akubernetes-csi+org%3Akubernetes-client+is%3Aopen+is%3Aissue+label%3A%22good+first+issue%22&type=Issues')
            self.assert_temp_redirect(base + 'help-wanted',
                'https://github.com/search?q=org%3Akubernetes+org%3Akubernetes-sigs+org%3Akubernetes-csi+org%3Akubernetes-client+is%3Aopen+is%3Aissue+label%3A%22help+wanted%22&type=Issues')
            self.assert_temp_redirect(
                base + 'oncall',
                'https://storage.googleapis.com/test-infra-oncall/oncall.html')
            self.assert_temp_redirect(base + 'owners',
                'https://github.com/kubernetes/community/blob/master/contributors/guide/owners.md')
            self.assert_temp_redirect(base + 'owners/$ghuser',
                'https://cs.k8s.io/?q=$ghuser&i=fosho&files=OWNERS&excludeFiles=vendor%2F&repos=',
                 ghuser=rand_num())
            self.assert_temp_redirect(
                base + 'partner-request',
                'https://docs.google.com/forms/d/e/1FAIpQLSdN1KtSKX2VAOPGABFlShkSd6CajQynoL4QCVtY0dj76MNDKg/viewform')
            self.assert_temp_redirect(
                base + 'start',
                'https://kubernetes.io/docs/setup/')
            self.assert_temp_redirect(
                base + 'test-history',
                'https://storage.googleapis.com/kubernetes-test-history/static/index.html')
            self.assert_temp_redirect(
                base + 'triage',
                'https://storage.googleapis.com/k8s-gubernator/triage/index.html')
            self.assert_temp_redirect(
                base + 'test-health',
                'http://velodrome.k8s.io/dashboard/db/bigquery-metrics')
            self.assert_temp_redirect(
                base + 'pr-dashboard',
                'https://gubernator.k8s.io/pr')

            self.assert_temp_redirect(
                base + 'stuck-prs',
                'https://github.com/kubernetes/kubernetes/pulls?utf8=%E2%9C%93&q=is%3Apr%20is%3Aopen%20label%3Algtm%20label%3Aapproved%20-label%3Ado-not-merge%20-label%3Aneeds-rebase%20sort%3Aupdated-asc%20-status%3Asuccess')
            self.assert_temp_redirect(
                base + 'needs-ok-to-test',
                'https://github.com/search?q=org%3Akubernetes+org%3Akubernetes-sigs+org%3Akubernetes-csi+org%3Akubernetes-client+is%3Aopen+is%3Apr+label%3Aneeds-ok-to-test+label%3A%22cncf-cla%3A+yes%22+-label%3Aneeds-rebase&type=Issues')

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

    def test_blog(self):
        for base in ('blog.k8s.io', 'blog.kubernetes.io'):
            self.assert_temp_redirect(base, 'https://kubernetes.io/blog/')
            self.assert_temp_redirect(base + '/$path',
                'https://kubernetes.io/blog/$path', path=rand_num())

    def test_ci_test(self):
        base = 'ci-test.kubernetes.io'
        self.assert_temp_redirect(base, 'https://console.developers.google.com/storage/browser/kubernetes-jenkins/logs')

        # trailing slash
        self.assert_temp_redirect(base + '/',
            'https://console.developers.google.com/storage/browser/kubernetes-jenkins/logs')

        # trailing slash
        self.assert_temp_redirect(base + '/e2e/',
            'https://console.developers.google.com/storage/browser/kubernetes-jenkins/logs/e2e')

        num = rand_num()
        # numeric with trailing slash
        self.assert_temp_redirect(base + '/e2e/$num/',
            'https://k8s-gubernator.appspot.com/build/kubernetes-jenkins/logs/e2e/$num',
            num=num)
        # numeric without trailing slash
        self.assert_temp_redirect(base + '/e2e/$num',
            'https://k8s-gubernator.appspot.com/build/kubernetes-jenkins/logs/e2e/$num',
            num=num)

        # no trailing slash
        self.assert_temp_redirect(base + '/e2e/$num/file',
            'https://storage.cloud.google.com/kubernetes-jenkins/logs/e2e/$num/file',
            num=num)

    def test_code(self):
        path = rand_num()
        for base in ('changelog.kubernetes.io', 'changelog.k8s.io'):
            self.assert_temp_redirect(base,
                    'https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/README.md')
            self.assert_temp_redirect(base + '/$path',
                'https://github.com/kubernetes/kubernetes/releases/tag/$path',
                path=path)
        for base in ('code.kubernetes.io', 'code.k8s.io'):
            self.assert_temp_redirect(base + '/$path',
                'https://github.com/kubernetes/kubernetes/tree/master/$path',
                path=path)

    def test_dl(self):
        for base in ('dl.k8s.io', 'dl.kubernetes.io'):
            # Valid release version numbers
            for extra in ('', '-alpha.$rc_ver', '-beta.$rc_ver', '-rc.$rc_ver'):
                self.assert_temp_redirect(
                    base + '/v$major_ver.$minor_ver.$patch_ver' + extra + '/$path',
                    'https://storage.googleapis.com/kubernetes-release/release/v$major_ver.$minor_ver.$patch_ver' + extra + '/$path',
                    major_ver=rand_num(), minor_ver=rand_num(), patch_ver=rand_num(), rc_ver=rand_num(), path=rand_num())
            # Not a release version
            self.assert_temp_redirect(
                base + '/v8/engine',
                'https://storage.googleapis.com/kubernetes-release/v8/engine')
            # Not a valid release version (gamma)
            self.assert_temp_redirect(
                base + '/v1.2.3-gamma.4/kubernetes.tar.gz',
                'https://storage.googleapis.com/kubernetes-release/v1.2.3-gamma.4/kubernetes.tar.gz')
            # A few /ci/ tests
            self.assert_temp_redirect(
                base + '/ci/v$ver/$path',
                'https://storage.googleapis.com/kubernetes-release-dev/ci/v$ver/$path',
                ver=rand_num(), path=rand_num())
            self.assert_temp_redirect(
                base + '/ci/latest-$ver.txt',
                'https://storage.googleapis.com/kubernetes-release-dev/ci/latest-$ver.txt',
                ver=rand_num())
            self.assert_temp_redirect(
                base + '/ci-cross/v$ver/$path',
                'https://storage.googleapis.com/kubernetes-release-dev/ci-cross/v$ver/$path',
                ver=rand_num(), path=rand_num())
            # Base case
            self.assert_temp_redirect(
                base + '/$path',
                'https://storage.googleapis.com/kubernetes-release/$path',
                path=rand_num())

    def test_docs(self):
        for base in ('docs.k8s.io', 'docs.kubernetes.io'):
            self.assert_temp_redirect(base, 'https://kubernetes.io/docs/')
            ver = '%d.%d' % (rand_num(), rand_num())
            self.assert_temp_redirect(base + '/v$ver', 'https://kubernetes.io/docs', ver=ver)
            path = rand_num()
            self.assert_temp_redirect(base + '/v$ver/$path', 'https://kubernetes.io/docs/$path', ver=ver, path=path)
            self.assert_temp_redirect(base + '/$path', 'https://kubernetes.io/docs/$path', path=path)

    def test_examples(self):
        for base in ('examples.k8s.io', 'examples.kubernetes.io'):
            self.assert_temp_redirect(base, 'https://github.com/kubernetes/examples/tree/master/')
            self.assert_temp_redirect(base + '/', 'https://github.com/kubernetes/examples/tree/master/')

            ver = '%d.%d' % (rand_num(), rand_num())
            self.assert_temp_redirect(base + '/v$ver',
                'https://github.com/kubernetes/kubernetes/tree/release-$ver/examples',
                ver=ver)
            self.assert_temp_redirect(base + '/v$ver/$path',
                'https://github.com/kubernetes/kubernetes/tree/release-$ver/examples/$path',
                ver=ver, path=rand_num())

    def test_features(self):
        for base in ('features.k8s.io', 'feature.k8s.io',
                     'features.kubernetes.io', 'feature.kubernetes.io'):
            self.assert_temp_redirect(base,
                'https://github.com/kubernetes/features/issues/',
                path=rand_num())
            self.assert_temp_redirect(base + '/$path',
                'https://github.com/kubernetes/features/issues/$path',
                path=rand_num())

    def test_git(self):
        for base in ('git.k8s.io', 'git.kubernetes.io'):
            self.assert_temp_redirect(base,
                'https://github.com/kubernetes/')
            self.assert_temp_redirect(base + '/$repo',
                'https://github.com/kubernetes/$repo/',
                 repo=rand_num())
            self.assert_temp_redirect(base + '/$repo/',
                'https://github.com/kubernetes/$repo/',
                 repo=rand_num())
            self.assert_temp_redirect(base + '/$repo/$path',
                'https://github.com/kubernetes/$repo/blob/master/$path',
                repo=rand_num(), path=rand_num())

    def test_issues(self):
        for base in ('issues.k8s.io', 'issue.k8s.io',
                     'issues.kubernetes.io', 'issue.kubernetes.io'):
            self.assert_temp_redirect(base + '/$path',
                'https://github.com/kubernetes/kubernetes/issues/$path',
                path=rand_num())

    def test_prs(self):
        for base in ('prs.k8s.io', 'pr.k8s.io',
                     'prs.kubernetes.io', 'pr.kubernetes.io'):
            self.assert_temp_redirect(base, 'https://github.com/kubernetes/kubernetes/pulls')
            self.assert_temp_redirect(base + '/$path',
                'https://github.com/kubernetes/kubernetes/pull/$path',
                path=rand_num())

    def test_pr_test(self):
        base = 'pr-test.kubernetes.io'
        self.assert_temp_redirect(base, 'https://gubernator.k8s.io')
        self.assert_temp_redirect(base + '/$id',
            'https://gubernator.k8s.io/pr/$id', id=rand_num())

    def test_release(self):
        for base in ('releases.k8s.io', 'rel.k8s.io',
                     'releases.kubernetes.io', 'rel.kubernetes.io'):
            self.assert_temp_redirect(base, 'https://github.com/kubernetes/kubernetes/releases')
            self.assert_temp_redirect(base + '/$ver/$path',
                'https://github.com/kubernetes/kubernetes/tree/$ver/$path',
                ver=rand_num(), path=rand_num())

    def test_submit_queue(self):
        for base in ('submit-queue.k8s.io', 'submit-queue.kubernetes.io'):
            self.assert_temp_redirect(base, 'https://prow.k8s.io/tide')
            self.assert_temp_redirect(base + '/$path', 'https://prow.k8s.io/tide',
                path=rand_num())

    def test_youtube(self):
        for base in ('yt.k8s.io', 'youtube.k8s.io', 'youtube.kubernetes.io', 'yt.kubernetes.io' ):
            self.assert_temp_redirect(base, 'https://www.youtube.com/c/kubernetescommunity')
            self.assert_temp_redirect(base + '/$path', 'https://www.youtube.com/c/kubernetescommunity',
                path=rand_num())

class ContentTest(HTTPTestCase):
    def assert_body_configmap(self, url, filename):
        print('GET', url)
        resp, body = self.do_get(url, 200)
        configmap = 'configmap-www-%s.yaml' % os.path.dirname(filename)
        with open(configmap) as f:
            expected_body = yaml.load(f, yaml.SafeLoader)['data'][os.path.basename(filename)]
        self.assertMultiLineEqual(body, expected_body,
                '\nGET "%s" got an unexpected body' % (url))

    def assert_body_url(self, url, expected_content_url):
        print('GET', url)
        resp, body = self.do_get(url, 200)
        expected_body = urllib.request.urlopen(expected_content_url).read().decode('utf-8')
        self.assertMultiLineEqual(body, expected_body,
                '\nGET "%s" got an unexpected body' % (url))

    def assert_body_go_get(self, host, org, repo, path):
        url = 'https://%s/%s/%s?go-get=1' % (host, repo, path)
        print('GET', url)
        expected_go_import = ("%(host)s/%(repo)s git https://github.com/%(org)s/%(repo)s"
                              % {'repo': repo, 'host': host, 'org': org})

        expected_go_source = ("%(host)s/%(repo)s https://github.com/%(org)s/%(repo)s "
                              "https://github.com/%(org)s/%(repo)s/tree/master{/dir} "
                              "https://github.com/%(org)s/%(repo)s/blob/master{/dir}/{file}#L{line}"
                              % {'repo': repo, 'host': host, 'org': org})

        resp, body = self.do_get(url, 200)
        p = GoMetaParser()
        p.feed(body)

        got_go_import = p.go_meta_tag('go-import')
        self.assertIsNotNone(got_go_import, '%s did not contain a go-import meta tag' % url)
        self.assertEqual(got_go_import, expected_go_import,
                         'go-import for %s did not match expected value.\ngot:  %s\nwant: %s'
                         % (url, got_go_import, expected_go_import))

        got_go_source = p.go_meta_tag('go-source')
        self.assertIsNotNone(got_go_source, '%s did not contain a go-source meta tag' % url)
        self.assertEqual(got_go_source, expected_go_source,
                         'go-source for %s did not match expected value.\ngot:  %s\nwant: %s'
                         % (url, got_go_source, expected_go_source))

    def test_go_get(self):
        # automatically configured repos
        for host, org in [('k8s.io', 'kubernetes'),]:
            self.assert_body_go_get(host, org, "example-repo", "pkg/subpath")
        for host, org in [('sigs.k8s.io', 'kubernetes-sigs'),]:
            self.assert_body_go_get(host, org, "example-repo", "pkg/subpath")

    def test_get(self):
        for base in ('http://get.k8s.io', 'http://get.kubernetes.io'):
            self.assert_body_configmap(base, 'get/get-kube-insecure.sh')

        for base in ('https://get.k8s.io', 'https://get.kubernetes.io'):
          self.assert_body_url(
              base,
              'https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/get-kube.sh')

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
        TARGET_IP = socket.gethostbyname('k8s.io')
        print('Testing against service at', TARGET_IP)
    else:
        print('TARGET_IP present in environment. Disabling SSL verification')
        SSL_VERIFY_DISABLE = True
    unittest.main()
