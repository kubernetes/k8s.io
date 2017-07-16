#!/usr/bin/env python

from __future__ import print_function

try:
    import httplib
    import urlparse
except ImportError:
    import http.client as httplib
    import urllib.parse as urlparse
import os
import random
import socket
import subprocess
import unittest
import urllib

import yaml

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
        conn = httplib.HTTPSConnection(TARGET_IP)
    conn.request('GET', path, headers={'Host': parsed.netloc})
    resp = conn.getresponse()
    body = resp.read().decode('utf8')
    resp.close()
    conn.close()
    return resp, body


class RedirTest(unittest.TestCase):
    def assert_code(self, url, expected_code):
        print('GET: %s => %s' % (url, expected_code))
        resp, body = do_get(url)
        self.assertEqual(resp.status, expected_code)

    def assert_scheme_redirect(self, url, expected_loc, expected_code, **kwargs):
        for k, v in kwargs.items():
            k = '$%s' % k
            v = '%s' % v
            url = url.replace(k, v)
            expected_loc = expected_loc.replace(k, v)
        print('REDIR: %s => %s' % (url, expected_loc))
        resp, body = do_get(url)
        self.assertEqual(resp.status, expected_code)
        self.assertEqual(resp.getheader('location'), expected_loc)

    def assert_redirect(self, partial_url, expected_loc, expected_code, **kwargs):
        for scheme in ('http', 'https'):
            self.assert_scheme_redirect(
                    scheme + '://' + partial_url, expected_loc, expected_code, **kwargs)

    def assert_temp_redirect(self, partial_url, expected_loc, **kwargs):
        self.assert_redirect(partial_url, expected_loc, 302, **kwargs)

    def assert_perm_redirect(self, partial_url, expected_loc, **kwargs):
        self.assert_redirect(partial_url, expected_loc, 301, **kwargs)

    def test_main(self):
        # Main URL.
        self.assert_code('https://kubernetes.io', 200)
        # Protocol upgrade.
        self.assert_scheme_redirect(
                'http://kubernetes.io', 'https://kubernetes.io/', 301)
        path = '/%s' % rand_num()
        # Protocol upgrade and path.
        self.assert_scheme_redirect(
                'http://kubernetes.io' + path, 'https://kubernetes.io' + path, 301)
        # Vanity domains.
        for url in ('k8s.io', 'kubernet.es'):
            self.assert_perm_redirect(url + path, 'https://kubernetes.io' + path)

    def test_go_get(self):
        self.assert_perm_redirect('k8s.io/kubernetes?go-get=1',
                'https://kubernetes.io/kubernetes?go-get=1')
        self.assert_code('https://kubernetes.io/kubernetes?go-get=1', 200)

    def test_go(self):
        for base in ('go.k8s.io/', 'go.kubernetes.io/'):
            self.assert_temp_redirect(base + 'bounty',
                'https://github.com/kubernetes/kubernetes.github.io/'
                'issues?q=is%3Aopen+is%3Aissue+label%3ABounty')
            self.assert_temp_redirect(base + 'help-wanted',
                'https://github.com/kubernetes/kubernetes/labels/help-wanted')
            self.assert_temp_redirect(
                base + 'oncall',
                'https://storage.googleapis.com/kubernetes-jenkins/oncall.html')
            self.assert_temp_redirect(
                base + 'partner-request',
                'https://docs.google.com/forms/d/e/1FAIpQLSdN1KtSKX2VAOPGABFlShkSd6CajQynoL4QCVtY0dj76MNDKg/viewform')
            self.assert_temp_redirect(base + 'start',
                'https://kubernetes.io/docs/getting-started-guides/')
            self.assert_temp_redirect(
                base + 'test-history',
                'https://storage.googleapis.com/kubernetes-test-history/static/index.html')
            self.assert_temp_redirect(
                base + 'triage',
                'https://storage.googleapis.com/k8s-gubernator/triage/index.html')
            self.assert_temp_redirect(
                base + 'test-health',
                'https://velodrome.k8s.io/dashboard/db/bigquery-metrics')

            self.assert_temp_redirect(
                base + 'stuck-prs',
                'https://github.com/kubernetes/kubernetes/pulls?utf8=%E2%9C%93&q=is%3Apr%20is%3Aopen%20label%3Algtm%20label%3Aapproved%20-label%3Ado-not-merge%20-label%3Aneeds-rebase%20sort%3Aupdated-asc%20-status%3Asuccess')

    def test_yum_test(self):
        for base in ('yum.k8s.io', 'yum.kubernetes.io'):
            self.assert_temp_redirect(base, 'https://packages.cloud.google.com/yum/')
            self.assert_temp_redirect(base + '/$id',
                'https://packages.cloud.google.com/yum/$id', id=rand_num())

    def test_apt_test(self):
        for base in ('apt.k8s.io', 'apt.kubernetes.io'):
            self.assert_temp_redirect(base, 'https://packages.cloud.google.com/apt/')
            self.assert_temp_redirect(base + '/$id',
                'https://packages.cloud.google.com/apt/$id', id=rand_num())

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
            self.assert_temp_redirect(base, 'http://kubernetes.io/docs/')
            ver = '%d.%d' % (rand_num(), rand_num())
            self.assert_temp_redirect(base + '/v$ver', 'http://kubernetes.io/docs', ver=ver)
            path = rand_num()
            self.assert_temp_redirect(base + '/v$ver/$path', 'http://kubernetes.io/docs/$path', ver=ver, path=path)
            self.assert_temp_redirect(base + '/$path', 'http://kubernetes.io/docs/$path', path=path)

    def test_examples(self):
        for base in ('examples.k8s.io', 'examples.kubernetes.io'):
            self.assert_temp_redirect(base, 'https://github.com/kubernetes/kubernetes/tree/master/examples/')

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
        self.assert_temp_redirect(base, 'https://k8s-gubernator.appspot.com')
        self.assert_temp_redirect(base + '/$id',
            'https://k8s-gubernator.appspot.com/pr/$id', id=rand_num())

    def test_release(self):
        for base in ('releases.k8s.io', 'rel.k8s.io',
                     'releases.kubernetes.io', 'rel.kubernetes.io'):
            self.assert_temp_redirect(base, 'https://github.com/kubernetes/kubernetes/releases')
            self.assert_temp_redirect(base + '/$ver/$path',
                'https://github.com/kubernetes/kubernetes/tree/$ver/$path',
                ver=rand_num(), path=rand_num())

    def test_reviewable(self):
        base = 'reviewable.k8s.io'
        self.assert_temp_redirect(base, 'https://reviewable.kubernetes.io/')
        self.assert_temp_redirect(base + '/$path', 'https://reviewable.kubernetes.io/$path',
            path=rand_num())

    def test_testgrid(self):
        for base in ('testgrid.k8s.io', 'testgrid.kubernetes.io'):
            self.assert_temp_redirect(base, 'https://k8s-testgrid.appspot.com/')
            self.assert_temp_redirect(base + '/$path', 'https://k8s-testgrid.appspot.com/$path',
                path=rand_num())


class ContentTest(unittest.TestCase):
    def assert_body_configmap(self, url, filename):
        print('GET', url)
        resp, body = do_get(url)
        self.assertEqual(resp.status, 200)
        configmap = 'configmap-www-%s.yaml' % os.path.dirname(filename)
        with open(configmap) as f:
            expected_body = yaml.load(f)['data'][os.path.basename(filename)]
        self.assertMultiLineEqual(body, expected_body)

    def assert_body_url(self, url, expected_content_url):
        print('GET', url)
        resp, body = do_get(url)
        self.assertEqual(resp.status, 200)
        expected_body = urllib.urlopen(expected_content_url).read()
        self.assertMultiLineEqual(body, expected_body)

    def test_go_get(self):
        base = 'https://kubernetes.io' # because everything ends up there
        suff = '%d?go-get=1' % rand_num()
        for pkg in ('kubernetes', 'heapster', 'kube-ui'):
            self.assert_body_configmap('%s/%s/%s' % (base, pkg, suff),
                'golang/%s.html' % pkg)
        resp, body = do_get(base + '/foobar/123?go-get=1')
        self.assertEqual(resp.status, 404)

    def test_get(self):
        for base in ('http://get.k8s.io', 'http://get.kubernetes.io'):
            self.assert_body_configmap(base, 'get/get-kube-insecure.sh')

        for base in ('https://get.k8s.io', 'https://get.kubernetes.io'):
          self.assert_body_url(
              base,
              'https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/get-kube.sh')


if __name__ == '__main__':
    TARGET_IP = os.environ.get('TARGET_IP')
    if not TARGET_IP:
        print('Attempting to autodiscover service TARGET_IP, set env var to override...')
        TARGET_IP = socket.gethostbyname('k8s.io')
        print('Testing against service at', TARGET_IP)
    unittest.main()
