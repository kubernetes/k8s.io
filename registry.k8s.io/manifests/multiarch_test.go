/*
Copyright 2026 The Kubernetes Authors.

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
	"context"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"sigs.k8s.io/yaml"
)

// allowedImages automatically skips some images that are not publishing multiarch images.
// If we start to publish multi-arch images for one of these projects, this list will need to be updated.
var allowedImages = []string{
	"registry.k8s.io/win-op-rdnss/win-op-rdnss",
	"registry.k8s.io/releng/releng-ci",
	"registry.k8s.io/security-profiles-operator/security-profiles-operator-bundle",
	"registry.k8s.io/security-profiles-operator/security-profiles-operator-catalog",
	"registry.k8s.io/artifact-promoter/kpromo",
	"registry.k8s.io/cloud-pv-vsphere/cloud-provider-vsphere",
	"registry.k8s.io/csi-vsphere/syncer",
	"registry.k8s.io/dra-example-driver/dra-example-driver",
	"registry.k8s.io/gateway-api-inference-extension/epp",
	"registry.k8s.io/gateway-api-inference-extension/bbr",
	"registry.k8s.io/gateway-api-inference-extension/latency-prediction-server",
	"registry.k8s.io/gateway-api-inference-extension/latency-training-server",

	// Note: etcd publishes per-arch tagged images.
	"registry.k8s.io/images/etcd",
}

// allowedImageSuffixes automatically allowlists an image that ends with the specified string e.g. kubectl-amd64
var allowedImageSuffixes = []string{
	"-amd64",
	"-arm64",
	"-ppc64le",
	"-s390x",
	"-arm",
	"-386",
}

// hasAllowedImageSuffix returns the suffix and true if the image name has an allow-listed suffix.
func hasAllowedImageSuffix(imageName string) (string, bool) {
	for _, suffix := range allowedImageSuffixes {
		if strings.HasSuffix(imageName, suffix) {
			return suffix, true
		}
	}
	return "", false
}

// allowedTagSuffixes automatically allowlists tagged images with a tag that ends with the specified string e.g. etcd:v3.6.11-amd64
var allowedTagSuffixes = []string{
	"-amd64",
	"-arm64",
	"-ppc64le",
	"-s390x",
	"-arm",
	"-386",
}

// hasAllowedTagSuffix returns the suffix and true if the image tag has an allow-listed tag suffix.
func hasAllowedTagSuffix(tag string) (string, bool) {
	for _, suffix := range allowedTagSuffixes {
		if strings.HasSuffix(tag, suffix) {
			return suffix, true
		}
	}
	return "", false
}

// imageItem is a simplified version of the promotion schema
type imageItem struct {
	Name string              `json:"name"`
	Dmap map[string][]string `json:"dmap"`
}

// TestNewImagesAreMultiArch verifies that any new images added to the registry are multi-arch,
// unless they are on one of the allowlists.
func TestNewImagesAreMultiArch(t *testing.T) {
	ctx := t.Context()

	allowedSet := make(map[string]bool)
	for _, img := range allowedImages {
		allowedSet[img] = true
	}

	// Get the base commit to compare against
	baseCommit := os.Getenv("PULL_BASE_SHA")
	if baseCommit == "" {
		// Local development fallbacks
		for _, ref := range []string{"origin/main", "main", "HEAD~1"} {
			cmd := exec.CommandContext(ctx, "git", "rev-parse", "--verify", ref)
			if err := cmd.Run(); err == nil {
				baseCommit = ref
				break
			}
		}
	}
	if baseCommit == "" {
		t.Skip("Could not determine base commit for git diff. Skipping multiarch check.")
		return
	}

	// Find repo root
	repoRootCmd := exec.CommandContext(ctx, "git", "rev-parse", "--show-toplevel")
	repoRootBytes, err := repoRootCmd.Output()
	if err != nil {
		t.Fatalf("failed to get repo root: %v", err)
	}
	repoRoot := strings.TrimSpace(string(repoRootBytes))

	// Run git diff to see if any images.yaml was modified
	cmd := exec.CommandContext(ctx, "git", "diff", "--name-only", baseCommit, "--", filepath.Join(repoRoot, "registry.k8s.io/images"))
	out, err := cmd.Output()
	if err != nil {
		t.Fatalf("failed to run git diff: %v", err)
	}

	modifiedFiles := []string{}
	lines := strings.Split(string(out), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line != "" && strings.HasSuffix(line, "images.yaml") {
			modifiedFiles = append(modifiedFiles, filepath.Join(repoRoot, line))
		}
	}

	if len(modifiedFiles) == 0 {
		t.Log("No images.yaml files modified in this PR/branch. Skipping multi-arch check.")
		return
	}

	t.Logf("Found %d modified images.yaml files. Validating new digests...", len(modifiedFiles))

	for _, currentPath := range modifiedFiles {
		// Extract staging project name from path
		parentDir := filepath.Base(filepath.Dir(currentPath))
		projectName := parentDir

		// Get base version of images.yaml relative to repo root
		relPath, err := filepath.Rel(repoRoot, currentPath)
		if err != nil {
			t.Fatalf("failed to get relative path for %s: %v", currentPath, err)
		}

		// Load current digests
		currBytes, err := os.ReadFile(currentPath)
		if err != nil {
			if os.IsNotExist(err) {
				t.Logf("File %s was deleted. Skipping.", currentPath)
				continue
			}
			t.Fatalf("failed to read current file %s: %v", currentPath, err)
		}
		var currItems []imageItem
		if err := yaml.Unmarshal(currBytes, &currItems); err != nil {
			t.Fatalf("failed to unmarshal current file %s: %v", currentPath, err)
		}

		// Load base digests
		var baseItems []imageItem
		gitShowCmd := exec.CommandContext(ctx, "git", "show", fmt.Sprintf("%s:%s", baseCommit, relPath))
		baseBytes, err := gitShowCmd.Output()
		if err == nil {
			if err := yaml.Unmarshal(baseBytes, &baseItems); err != nil {
				t.Fatalf("failed to unmarshal base file for %s: %v", currentPath, err)
			}
		} else {
			t.Logf("images.yaml for %s does not exist in base commit %s. Treating as a new file.", projectName, baseCommit)
		}

		// Create map of base digests for comparison
		baseDigests := make(map[string]bool)
		for _, item := range baseItems {
			for digest := range item.Dmap {
				baseDigests[digest] = true
			}
		}

		// Read corresponding promoter-manifest.yaml to find source registry
		promoterPath := filepath.Join(repoRoot, "registry.k8s.io/manifests", projectName, "promoter-manifest.yaml")
		promoterBytes, err := os.ReadFile(promoterPath)
		if err != nil {
			t.Fatalf("failed to read promoter-manifest.yaml for %s: %v", projectName, err)
		}
		var promoter Manifest // Uses Manifest defined in manifest_test.go
		if err := yaml.Unmarshal(promoterBytes, &promoter); err != nil {
			t.Fatalf("failed to unmarshal promoter-manifest.yaml for %s: %v", projectName, err)
		}

		var srcRegistry string
		for _, reg := range promoter.Registries {
			if reg.Src {
				srcRegistry = reg.Name
				break
			}
		}
		if srcRegistry == "" {
			t.Fatalf("could not find src registry in promoter-manifest.yaml for %s", projectName)
		}

		registryHost, registryPath, err := splitRegistry(srcRegistry)
		if err != nil {
			t.Fatalf("failed to parse src registry for %s: %v", projectName, err)
		}

		// Check newly added digests
		for _, item := range currItems {
			imageName := item.Name
			// Skip Helm charts OCI artifacts
			if strings.HasPrefix(imageName, "charts/") || strings.Contains(imageName, "charts") {
				t.Logf("Skipping Helm chart artifact check: %s/%s", projectName, imageName)
				continue
			}

			destImageBase := getProposedDestinationImage(promoter, imageName)

			// Check if the image is in the single-arch allowlist
			if allowedSet[destImageBase] {
				t.Logf("Skipping multi-arch check for allowed single-arch image: %s", destImageBase)
				continue
			}

			// Check if the image has an arch-specific suffix
			if suffix, ok := hasAllowedImageSuffix(imageName); ok {
				t.Logf("Skipping multi-arch check for arch-specific image (with known suffix %s): %s", suffix, destImageBase)
				continue
			}

			for digest, tags := range item.Dmap {
				if baseDigests[digest] {
					// Existing digest, skip
					continue
				}

				allTagsAllowlisted := true
				for _, tag := range tags {
					if _, ok := hasAllowedTagSuffix(tag); !ok {
						allTagsAllowlisted = false
					}
				}

				if allTagsAllowlisted {
					t.Logf("Skipping multi-arch check for image with all allow-listed tags: %s/%s (tags: %s)", projectName, imageName, strings.Join(tags, ", "))
					continue
				}

				destImages := formatDestImages(destImageBase, tags)
				t.Logf("Validating new digest: %s/%s@%s (proposed destination: %s)", projectName, imageName, digest, destImages)

				// Query registry to check if it's multi-arch
				image := &image{
					Host:           registryHost,
					RepositoryPath: fmt.Sprintf("%s/%s", registryPath, imageName),
					Digest:         digest,
				}
				multiArch, err := checkMultiArch(ctx, image)
				if err != nil {
					t.Errorf("ERROR: Failed to verify multi-arch status for %s/%s@%s (proposed destination: %s): %v", projectName, imageName, digest, destImages, err)
					continue
				}

				if !multiArch {
					t.Errorf("FAIL: Image %s is a single-architecture image! All new promoted images must be multi-architecture, unless added to the allowedImages list in multiarch_test.go.", destImages)
				} else {
					t.Logf("PASS: Image %s is multi-architecture.", destImages)
				}
			}
		}
	}
}

// splitRegistry splits a registry string into host and path parts.
func splitRegistry(srcRegistry string) (string, string, error) {
	parts := strings.SplitN(srcRegistry, "/", 2)
	if len(parts) != 2 {
		return "", "", fmt.Errorf("invalid source registry format: %s", srcRegistry)
	}
	return parts[0], parts[1], nil
}

// image is the image we are checking
type image struct {
	Host           string
	RepositoryPath string
	Digest         string
}

func (i image) url() string {
	return fmt.Sprintf("https://%s/v2/%s/manifests/%s", i.Host, i.RepositoryPath, i.Digest)
}

func checkMultiArch(ctx context.Context, i *image) (bool, error) {
	u := i.url()
	req, err := http.NewRequestWithContext(ctx, "GET", u, nil)
	if err != nil {
		return false, fmt.Errorf("failed to create request for url %q: %w", u, err)
	}

	req.Header.Set("Accept", "application/vnd.docker.distribution.manifest.v2+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.manifest.v1+json, application/vnd.oci.image.index.v1+json")

	client := &http.Client{
		Timeout: 15 * time.Second,
	}
	resp, err := client.Do(req)
	if err != nil {
		return false, fmt.Errorf("failed to fetch url %q: %w", u, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return false, fmt.Errorf("registry returned status %d (%q) for url %q", resp.StatusCode, resp.Status, u)
	}

	contentType := resp.Header.Get("Content-Type")
	if contentType == "application/vnd.docker.distribution.manifest.list.v2+json" ||
		contentType == "application/vnd.oci.image.index.v1+json" {
		return true, nil
	}

	if contentType == "application/vnd.docker.distribution.manifest.v2+json" ||
		contentType == "application/vnd.oci.image.manifest.v1+json" {
		return false, nil
	}

	return false, fmt.Errorf("unsupported manifest content-type %q for url %q", contentType, u)
}

// getProposedDestinationImage computes the proposed destination image name.
func getProposedDestinationImage(promoter Manifest, imageName string) string {
	var destReg string
	for _, reg := range promoter.Registries {
		if !reg.Src {
			destReg = reg.Name
			break
		}
	}
	if destReg == "" {
		return ""
	}

	// Trim the production registry prefix to get the path under registry.k8s.io
	var trimmedPath string
	for _, pr := range ProdRegistries {
		if strings.HasPrefix(destReg, pr) {
			trimmedPath = strings.TrimPrefix(destReg, pr)
			break
		}
	}
	if trimmedPath == "" {
		// Fallback if no production registry prefix matches
		parts := strings.Split(destReg, "/")
		trimmedPath = parts[len(parts)-1]
	}

	return fmt.Sprintf("registry.k8s.io/%s/%s", trimmedPath, imageName)
}

// formatDestImages formats the destination images for logging.
func formatDestImages(destImageBase string, tags []string) string {
	if destImageBase == "" {
		return ""
	}
	var dests []string
	for _, tag := range tags {
		dests = append(dests, fmt.Sprintf("%s:%s", destImageBase, tag))
	}
	return strings.Join(dests, ", ")
}
