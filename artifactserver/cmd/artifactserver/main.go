/*
Copyright 2021 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package main

import (
	"flag"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"

	"k8s.io/klog"
)

var listen = ":8080"

func main() {
	klog.InitFlags(nil)

	flag.Set("logtostderr", "true")
	flag.StringVar(&listen, "listen", listen, "endpoint on which to listen")
	flag.Parse()

	err := run()
	if err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		os.Exit(1)
	} else {
		os.Exit(0)
	}
}

func run() error {
	r := &Redirector{
		backends: make(map[string]*Backend),
	}

	// TODO: Load from configmap or similar
	if err := r.SetBackend(&Backend{
		Name:       "kops",
		Host:       "kubeupv2.s3.amazonaws.com",
		PathPrefix: "kops/",
	}); err != nil {
		return err
	}

	httpServer := &http.Server{
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  120 * time.Second,
		Handler:      r,
		Addr:         listen,
	}

	klog.Infof("listening on %s", listen)
	err := httpServer.ListenAndServe()
	if err != nil {
		return fmt.Errorf("error from ListenAndServe: %v", err)
	}
	return nil
}

// Redirector acts as an HTTP server, redirecting requests to backends
type Redirector struct {
	// backends is a map from subtrees to backends
	backends map[string]*Backend
}

// Backend holds the data for a target backend; we redirect requests to that backend
type Backend struct {
	// Name of the subtree to serve: artifacts.k8s.io/<name>/...
	Name string

	// Host is the host to which we redirect - storage.googleapis.com for GCS, <bucket>.s3.amazonaws.com for AWS, etc
	Host string

	// PathPrefix is the prefix we insert into the path to force requests into a subpath of the target
	PathPrefix string
}

func (r *Redirector) SetBackend(b *Backend) error {
	if b.Name == "" {
		return fmt.Errorf("backend did not have name")
	}

	b.PathPrefix = strings.TrimSuffix(b.PathPrefix, "/")
	r.backends[b.Name] = b
	return nil
}

func (s *Redirector) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	klog.Infof("request %s %s", r.Method, r.URL)

	tokens := strings.Split(strings.TrimPrefix(r.URL.Path, "/"), "/")

	if len(tokens) < 1 {
		klog.Infof("%s -> 404", r.URL.Path)
		w.WriteHeader(http.StatusNotFound)
		return
	}

	backend := s.backends[tokens[0]]

	if backend == nil {
		// healthz check endpoint
		if r.Method == "GET" && len(tokens) == 2 && tokens[0] == "_" && tokens[1] == "healthz" {
			klog.Infof("%s -> 200 OK", r.URL.Path)
			w.WriteHeader(http.StatusOK)
			return
		}

		klog.Infof("%s -> 404", r.URL.Path)
		w.WriteHeader(http.StatusNotFound)
		return
	}

	if r.Method != "GET" && r.Method != "HEAD" {
		klog.Infof("%s %s -> 405", r.Method, r.URL.Path)
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	target := &url.URL{
		Scheme: "https",
		Host:   backend.Host,
	}

	path := strings.TrimPrefix(r.URL.Path, "/"+backend.Name)
	path = strings.TrimPrefix(path, "/")
	target.Path = backend.PathPrefix + "/" + path

	klog.Infof("%s -> 302 %s", r.URL.Path, target)
	http.Redirect(w, r, target.String(), 302)
}
