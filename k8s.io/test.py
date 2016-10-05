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
import subprocess
import unittest

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
    def assert_redirect(self, url, expected_loc, **kwargs):
        for k, v in kwargs.items():
            k = '$%s' % k
            v = '%s' % v
            url = url.replace(k, v)
            expected_loc = expected_loc.replace(k, v)
        print('REDIR: %s => %s' % (url, expected_loc))
        resp, body = do_get(url)
        self.assertEqual(resp.status, 302)
        self.assertEqual(resp.getheader('location'), expected_loc)

    def test_main(self):
        path = '/%s' % rand_num()
        for url in ('http://k8s.io', 'https://k8s.io', 'http://kubernet.es'):
            self.assert_redirect(url + path, 'http://kubernetes.io' + path)

    def test_go(self):
        # The go. subdomains are not on the SSL cert
        for base in ('http://go.k8s.io/', 'http://go.kubernetes.io/'):
            self.assert_redirect(base + 'bounty',
                'https://github.com/kubernetes/kubernetes.github.io/'
                'issues?q=is%3Aopen+is%3Aissue+label%3ABounty')
            self.assert_redirect(base + 'help-wanted',
                'https://github.com/kubernetes/kubernetes/labels/help-wanted')
            self.assert_redirect(base + 'start',
                'http://kubernetes.io/docs/getting-started-guides/')

    # TODO: external go-get ???

    def test_yum_test(self):
        # FIXME: https://yum.kubernetes.io is not on the cert
        for base in ('http://yum.k8s.io', 'http://yum.kubernetes.io'):
            self.assert_redirect(base, 'https://packages.cloud.google.com/yum/')
            self.assert_redirect(base + '/$id',
                'https://packages.cloud.google.com/yum/$id', id=rand_num())

    def test_apt_test(self):
        # FIXME: https://apt.kubernetes.io is not on the cert
        for base in ('http://apt.k8s.io', 'http://apt.kubernetes.io'):
            self.assert_redirect(base, 'https://packages.cloud.google.com/apt/')
            self.assert_redirect(base + '/$id',
                'https://packages.cloud.google.com/apt/$id', id=rand_num())

    def test_ci_test(self):
        # FIXME: https://ci-test.kubernetes.io is not on the cert
        base = 'http://ci-test.kubernetes.io'
        self.assert_redirect(base, 'https://console.developers.google.com/storage/browser/kubernetes-jenkins/logs')

        # trailing slash
        self.assert_redirect(base + '/',
            'https://console.developers.google.com/storage/browser/kubernetes-jenkins/logs')

        # trailing slash
        self.assert_redirect(base + '/e2e/',
            'https://console.developers.google.com/storage/browser/kubernetes-jenkins/logs/e2e')

        num = rand_num()
        # numeric with trailing slash
        self.assert_redirect(base + '/e2e/$num/',
            'https://k8s-gubernator.appspot.com/build/kubernetes-jenkins/logs/e2e/$num',
            num=num)
        # numeric without trailing slash
        self.assert_redirect(base + '/e2e/$num',
            'https://k8s-gubernator.appspot.com/build/kubernetes-jenkins/logs/e2e/$num',
            num=num)

        # no trailing slash
        self.assert_redirect(base + '/e2e/$num/file',
            'https://storage.cloud.google.com/kubernetes-jenkins/logs/e2e/$num/file',
            num=num)

    def test_code(self):
        # FIXME: https://code.kubernetes.io is not on the cert. Same for changelog.
        path = rand_num()
        for base in ('http://changelog.kubernetes.io', 'http://changelog.k8s.io'):
            self.assert_redirect(base + '/$path',
                'https://github.com/kubernetes/kubernetes/releases/tag/$path',
                path=path)
        for base in ('http://code.kubernetes.io', 'http://code.k8s.io'):
            self.assert_redirect(base + '/$path',
                'https://github.com/kubernetes/kubernetes/tree/master/$path',
                path=path)

    def test_dl(self):
        # FIXME: https://dl.{k8s,kubernetes}.io is not on the cert
        for base in ('http://dl.k8s.io', 'http://dl.kubernetes.io'):
            # Valid release version numbers
            for extra in ('', '-alpha.$rc_ver', '-beta.$rc_ver'):
                self.assert_redirect(
                    base + '/v$major_ver.$minor_ver.$patch_ver' + extra + '/$path',
                    'https://storage.googleapis.com/kubernetes-release/release/v$major_ver.$minor_ver.$patch_ver' + extra + '/$path',
                    major_ver=rand_num(), minor_ver=rand_num(), patch_ver=rand_num(), rc_ver=rand_num(), path=rand_num())
            # Not a release version
            self.assert_redirect(
                base + '/v8/engine',
                'https://storage.googleapis.com/kubernetes-release/v8/engine')
            # Not a valid release version (gamma)
            self.assert_redirect(
                base + '/v1.2.3-gamma.4/kubernetes.tar.gz',
                'https://storage.googleapis.com/kubernetes-release/v1.2.3-gamma.4/kubernetes.tar.gz')
            # A few /ci/ tests
            self.assert_redirect(
                base + '/ci/v$ver/$path',
                'https://storage.googleapis.com/kubernetes-release-dev/ci/v$ver/$path',
                ver=rand_num(), path=rand_num())
            self.assert_redirect(
                base + '/ci/latest-$ver.txt',
                'https://storage.googleapis.com/kubernetes-release-dev/ci/latest-$ver.txt',
                ver=rand_num())
            # Base case
            self.assert_redirect(
                base + '/$path',
                'https://storage.googleapis.com/kubernetes-release/$path',
                path=rand_num())

    def test_docs(self):
        # FIXME: https://docs.kubernetes.io is not on the cert
        for base in ('http://docs.k8s.io', 'https://docs.k8s.io', 'http://docs.kubernetes.io'):
            self.assert_redirect(base, 'http://kubernetes.io/docs/')
            ver = '%d.%d' % (rand_num(), rand_num())
            self.assert_redirect(base + '/v$ver', 'http://kubernetes.io/docs', ver=ver)
            path = rand_num()
            self.assert_redirect(base + '/v$ver/$path', 'http://kubernetes.io/docs/$path', ver=ver, path=path)
            self.assert_redirect(base + '/$path', 'http://kubernetes.io/docs/$path', path=path)

    def test_examples(self):
        # FIXME: https://examples.kubernetes.io is not on the cert
        for base in ('http://examples.k8s.io', 'https://examples.k8s.io', 'http://examples.kubernetes.io'):
            self.assert_redirect(base, 'https://github.com/kubernetes/kubernetes/tree/master/examples/')

            ver = '%d.%d' % (rand_num(), rand_num())
            self.assert_redirect(base + '/v$ver',
                'https://github.com/kubernetes/kubernetes/tree/release-$ver/examples',
                ver=ver)
            self.assert_redirect(base + '/v$ver/$path',
                'https://github.com/kubernetes/kubernetes/tree/release-$ver/examples/$path',
                ver=ver, path=rand_num())

    def test_features(self):
        # FIXME: Make certs cover https://feature{s,}.{k8s,kubernetes}.io
        for base in ('http://features.k8s.io', 'http://feature.k8s.io',
                     'http://features.kubernetes.io', 'https://feature.kubernetes.io'):
            self.assert_redirect(base,
                'https://github.com/kubernetes/features/issues/',
                path=rand_num())
            self.assert_redirect(base + '/$path',
                'https://github.com/kubernetes/features/issues/$path',
                path=rand_num())

    def test_issues(self):
        # FIXME: https://issue.kubernetes.io is not on the cert
        for base in ('http://issues.k8s.io', 'https://issues.k8s.io', 'http://issue.kubernetes.io'):
            self.assert_redirect(base + '/$path',
                'https://github.com/kubernetes/kubernetes/issues/$path',
                path=rand_num())

    def test_prs(self):
        # FIXME: https://pr.kubernetes.io is not on the cert
        for base in ('http://prs.k8s.io', 'https://prs.k8s.io', 'http://pr.kubernetes.io'):
            self.assert_redirect(base, 'https://github.com/kubernetes/kubernetes/pulls')
            self.assert_redirect(base + '/$path',
                'https://github.com/kubernetes/kubernetes/pull/$path',
                path=rand_num())

    def test_pr_test(self):
        # PR tests
        # FIXME: https://pr-test.kubernetes.io is not on the cert.
        base = 'http://pr-test.kubernetes.io'
        self.assert_redirect(base, 'https://k8s-gubernator.appspot.com')
        self.assert_redirect(base + '/$id',
            'https://k8s-gubernator.appspot.com/pr/$id', id=rand_num())

    def test_release(self):
        # FIXME: https://releases.kubernetes.io is not on the cert
        # FIXME: https://rel.kubernetes.io is not on the cert
        for base in '''http://releases.k8s.io
                 https://releases.k8s.io
                 http://rel.k8s.io
                 https://rel.k8s.io
                 http://releases.kubernetes.io
                 http://rel.kubernetes.io'''.split():
            self.assert_redirect(base, 'https://github.com/kubernetes/kubernetes/releases')
            self.assert_redirect(base + '/$ver/$path',
                'https://github.com/kubernetes/kubernetes/tree/$ver/$path',
                ver=rand_num(), path=rand_num())

    def test_reviewable(self):
        # FIXME: https://reviewable.k8s.io is not on the cert
        for base in ('http://reviewable.k8s.io',):
            self.assert_redirect(base, 'https://reviewable.kubernetes.io/')
            self.assert_redirect(base + '/$path', 'https://reviewable.kubernetes.io/$path',
                path=rand_num())

    def test_testgrid(self):
        # Testgrid
        # FIXME: https://testgrid.k8s.io is not on the cert
        for base in ('http://testgrid.k8s.io', 'http://testgrid.kubernetes.io'):
            self.assert_redirect(base, 'https://k8s-testgrid.appspot.com/')
            self.assert_redirect(base + '/$path', 'https://k8s-testgrid.appspot.com/$path',
                path=rand_num())


class ContentTest(unittest.TestCase):
    def assert_body(self, url, filename):
        print('GET', url)
        resp, body = do_get(url)
        self.assertEqual(resp.status, 200)
        configmap = 'configmap-www-%s.yaml' % os.path.dirname(filename)
        with open(configmap) as f:
            expected_body = yaml.load(f)['data'][os.path.basename(filename)]
        self.assertMultiLineEqual(body, expected_body)

    def test_go_get(self):
        for base in ('http://k8s.io', 'https://k8s.io'):
            suff = '%d?go-get=1' % rand_num()
            for pkg in ('kubernetes', 'heapster', 'kube-ui'):
                self.assert_body('%s/%s/%s' % (base, pkg, suff),
                    'golang/%s.html' % pkg)
            resp, body = do_get(base + '/foobar/123?go-get=1')
            self.assertEqual(resp.status, 404)

    def test_get(self):
        for base in ('http://get.k8s.io', 'http://get.kubernetes.io'):
            self.assert_body(base, 'get/get-kube-insecure.sh')

        # FIXME: https://get.kubernetes.io is not on the cert
        for base in ('https://get.k8s.io',):
            self.assert_body(base, 'get/get-kube-secure.sh')


if __name__ == '__main__':
    TARGET_IP = os.environ.get('TARGET_IP')
    if not TARGET_IP:
        print('Attempting to autodiscover service TARGET_IP, set env var to override...')
        TARGET_IP = subprocess.check_output(['dig', '+short', 'k8s.io'])
        print('Testing against service at', TARGET_IP)
    unittest.main()
