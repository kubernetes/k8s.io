/*
Copyright 2022 The Kubernetes Authors.

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

package manifest

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"k8s.io/apimachinery/pkg/util/sets"
	"sigs.k8s.io/yaml"
)

func TestManifestLooksReasonable(t *testing.T) {
	err := filepath.Walk(".",
		func(currPath string, info os.FileInfo, err error) error {
			if err != nil {
				return err
			}
			// ignore everything but yaml files
			if info.IsDir() || !strings.HasSuffix(currPath, ".yaml") {
				return nil
			}
			return manifestLooksReasonable(currPath)
		})
	if err != nil {
		t.Fatal(err)
	}
}

type Registry struct {
	Name string `json:"name"`
	Src  bool   `json:"src"`
}
type Manifest struct {
	Registries []Registry `json:"registries"`
}

// TODO: If you add any production registries you will have to update this list 🤷
var ProdRegistries []string = []string{
	"asia.gcr.io/k8s-artifacts-prod/",
	"us.gcr.io/k8s-artifacts-prod/",
	"eu.gcr.io/k8s-artifacts-prod/",
	"asia-east1-docker.pkg.dev/k8s-artifacts-prod/images/",
	"asia-south1-docker.pkg.dev/k8s-artifacts-prod/images/",
	"asia-northeast1-docker.pkg.dev/k8s-artifacts-prod/images/",
	"asia-northeast2-docker.pkg.dev/k8s-artifacts-prod/images/",
	"australia-southeast1-docker.pkg.dev/k8s-artifacts-prod/images/",
	"europe-north1-docker.pkg.dev/k8s-artifacts-prod/images/",
	"europe-southwest1-docker.pkg.dev/k8s-artifacts-prod/images/",
	"europe-west1-docker.pkg.dev/k8s-artifacts-prod/images/",
	"europe-west2-docker.pkg.dev/k8s-artifacts-prod/images/",
	"europe-west4-docker.pkg.dev/k8s-artifacts-prod/images/",
	"europe-west8-docker.pkg.dev/k8s-artifacts-prod/images/",
	"europe-west9-docker.pkg.dev/k8s-artifacts-prod/images/",
	"southamerica-west1-docker.pkg.dev/k8s-artifacts-prod/images/",
	"us-central1-docker.pkg.dev/k8s-artifacts-prod/images/",
	"us-east1-docker.pkg.dev/k8s-artifacts-prod/images/",
	"us-east4-docker.pkg.dev/k8s-artifacts-prod/images/",
	"us-east5-docker.pkg.dev/k8s-artifacts-prod/images/",
	"us-south1-docker.pkg.dev/k8s-artifacts-prod/images/",
	"us-west1-docker.pkg.dev/k8s-artifacts-prod/images/",
	"us-west2-docker.pkg.dev/k8s-artifacts-prod/images/",
}

func manifestLooksReasonable(manifestPath string) error {
	contents, err := os.ReadFile(manifestPath)
	if err != nil {
		return err
	}
	var m Manifest
	if err := yaml.Unmarshal(contents, &m); err != nil {
		return err
	}
	// ensure all registries exist and have the same image names
	nameToRegistries := map[string]sets.String{}
	numTopLevelImagesFound := 0
	numSrc := 0
	for _, r := range m.Registries {
		// check number of src entries don't constrain values
		if r.Src {
			numSrc++
			continue
		}
		// find the matching production registry
		foundRegistry := false
		for _, pr := range ProdRegistries {
			if strings.HasPrefix(r.Name, pr) {
				imageName := strings.TrimPrefix(r.Name, pr)
				if _, exists := nameToRegistries[imageName]; !exists {
					nameToRegistries[imageName] = sets.NewString()
				}
				nameToRegistries[imageName].Insert(pr)
				foundRegistry = true
				break
			}
			// special case for top-level image promotion
			if r.Name+"/" == pr {
				numTopLevelImagesFound++
				foundRegistry = true
				break
			}
		}
		if !foundRegistry {
			return fmt.Errorf("%q does not match any known prod registries in %q", r.Name, manifestPath)
		}
	}
	// check results
	// for each image name we find, ensure it is in all prod registries
	for imageName, registries := range nameToRegistries {
		if len(registries) != len(ProdRegistries) {
			return fmt.Errorf("did not find all production registries, %d found but expected %d for image %q in %q", len(registries), len(ProdRegistries), imageName, manifestPath)
		}
	}
	// if we found any top level promotions, we should find all prod registries
	if numTopLevelImagesFound != 0 && numTopLevelImagesFound != len(ProdRegistries) {
		return fmt.Errorf("found %d top-level image promotions but expected 0 or %d in %q", numTopLevelImagesFound, len(ProdRegistries), manifestPath)
	}
	// there should be exactly one src registry
	if numSrc != 1 {
		return fmt.Errorf("expected exactly one src entry but got %d in %q", numSrc, manifestPath)
	}
	return nil
}
