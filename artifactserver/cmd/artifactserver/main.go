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
	"io/ioutil"
	"net/http"
	"net/url"
	"os"
	"sigs.k8s.io/yaml"
	"strings"
	"time"

	"k8s.io/klog"
)

var listen = ":8080"
var config = &Redirector{}

func main() {
	klog.InitFlags(nil)

	configPath := "config.yaml"
	flag.Set("logtostderr", "true")
	flag.StringVar(&listen, "listen", listen, "endpoint on which to listen")
	flag.StringVar(&configPath, "config", configPath, "path to a config.yaml")
	flag.Parse()

	data, err := ioutil.ReadFile(configPath)
	if err != nil {
		klog.Fatalf("File reading error: %v\n", err)
	}
	err = yaml.Unmarshal(data, &config)
	if err != nil {
		klog.Fatalf("Yaml unmarshalling error: %v\n", err)
	}
	fmt.Println("# artifactserver Config")
	fmt.Println(string(data))

	err = run()
	if err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		os.Exit(1)
	} else {
		os.Exit(0)
	}
}

func run() error {
	httpServer := &http.Server{
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  120 * time.Second,
		Handler:      config,
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
	Backends map[string]*Backend `yaml:"backends"`
}

// Conditions for rewriting a request a given backend
type Conditions struct {
	// Headers are HTTP header and value key pairs
	Headers map[string]string `yaml:"headers"`

	// Paths are request paths to choose the backend
	Paths []string `yaml:"paths"`
}

// Backend holds the data for a target backend; we redirect requests to that backend
type Backend struct {
	// Host is the host to which we redirect - storage.googleapis.com for GCS, <bucket>.s3.amazonaws.com for AWS, etc
	Host string `yaml:"host"`

	// PathPrefix is the prefix we insert into the path to force requests into a subpath of the target
	PathPrefix string `yaml:"pathPrefix"`

	// Conditions are conditions for whether the request should be rewritten to a given backend
	Conditions Conditions `yaml:"conditions"`
}

func (r *Redirector) SetBackend(b *Backend) error {
	b.PathPrefix = strings.TrimSuffix(b.PathPrefix, "/")
	r.Backends[b.Host] = b
	return nil
}

func (s *Redirector) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	sourceIP := r.Header.Get("X-Real-Ip")
	if sourceIP == "" {
		sourceIP = r.RemoteAddr
	}
	klog.Infof("%v %v %v %v %v %s\n", r.Method, r.URL, r.Proto, r.Response, sourceIP)

	tokens := strings.Split(strings.TrimPrefix(r.URL.Path, "/"), "/")

	if len(tokens) < 1 {
		klog.Infof("%s -> 404", r.URL.Path)
		w.WriteHeader(http.StatusNotFound)
		return
	}

	var backend *Backend
	for _, v := range s.Backends {
		if backend == nil {
			backend = v
		}
		for hk, hv := range v.Conditions.Headers {
			if r.Header.Get(hk) == hv {
				backend = v
			}
		}
		for _, p := range v.Conditions.Paths {
			if r.URL.Path == p && p != "" {
				backend = v
			}
		}
	}

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

	if !(r.Method == "GET" || r.Method == "HEAD") {
		klog.Infof("%s %s -> 405", r.Method, r.URL.Path)
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	target := &url.URL{
		Scheme: "https",
		Host:   backend.Host,
	}

	path := strings.TrimPrefix(r.URL.Path, "/")
	target.Path = backend.PathPrefix + "/" + path

	klog.Infof("%s -> 302 %s", r.URL.Path, target)
	http.Redirect(w, r, target.String(), 302)
}
