package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"

	"k8s.io/klog"

	"github.com/google/go-containerregistry/pkg/authn"
	"github.com/google/go-containerregistry/pkg/crane"
	"github.com/google/go-containerregistry/pkg/name"
	"github.com/google/go-containerregistry/pkg/v1/google"
	"github.com/google/go-containerregistry/pkg/v1/remote"
)

// Based on gcrane list command  https://github.com/google/go-containerregistry/blob/master/cmd/gcrane/cmd/list.go

func main() {
	ctx := context.Background()

	if err := run(ctx); err != nil {
		klog.Fatalf("unexpected error: %v", err)
	}
}

var remoteOptions []remote.Option

func run(ctx context.Context) error {
	root := "k8s.gcr.io"
	recursive := true

	remoteOptions = []remote.Option{
		remote.WithAuthFromKeychain(authn.DefaultKeychain),
	}

	if root == "k8s.gcr.io" {
		response, err := http.Get("https://k8s.gcr.io/v2/tags/list")
		if err != nil {
			return fmt.Errorf("error querying gcr root: %w", err)
		}

		b, err := ioutil.ReadAll(response.Body)
		if err != nil {
			return fmt.Errorf("error reading gcr root response: %w", err)
		}

		root := &Root{}
		if err := json.Unmarshal(b, root); err != nil {
			return fmt.Errorf("error parsing gcr root: %w", err)
		}

		for _, child := range root.Child {
			if err := dumpRepo(ctx, "k8s.gcr.io/"+child, recursive); err != nil {
				return err
			}
		}
		return nil
	}

	if err := dumpRepo(ctx, root, recursive); err != nil {
		return err
	}

	return nil
}

func dumpRepo(ctx context.Context, root string, recursive bool) error {
	klog.Infof("dumping %q", root)

	repo, err := name.NewRepository(root)
	if err != nil {
		return err
	}

	if recursive {
		if err := google.Walk(repo, dump, google.WithAuthFromKeychain(google.Keychain)); err != nil {
			return err
		}
		return nil
	}

	tags, err := google.List(repo, google.WithAuthFromKeychain(google.Keychain))
	if err != nil {
		return err
	}

	return dump(repo, tags, err)
}

func dump(repo name.Repository, tags *google.Tags, err error) error {
	if err != nil {
		return err
	}

	var out []*Row

	for _, manifest := range tags.Manifests {

		for _, tag := range manifest.Tags {
			/*
				ref, err := name.ParseReference(digest, repo.Registry)
				if err != nil {
					return fmt.Errorf("parsing reference %q: %v", r, err)
				}
				manifest, err := remote.Get(ref, remoteOptions...)
			*/

			src := repo.String() + ":" + tag
			manifest, err := crane.Manifest(src)
			if err != nil {
				return fmt.Errorf("fetching manifest %s: %v", src, err)
			}

			m := &DockerManifest{}
			if err := json.Unmarshal(manifest, m); err != nil {
				return fmt.Errorf("error parsing manifest %s: %w", src, err)
			}

			out = append(out, &Row{
				IsManifest: true,
				Digest:     m.Config.Digest,
				Image:      repo.String(),
				Tag:        tag,
			})

			for _, l := range m.Layers {
				out = append(out, &Row{
					IsManifest: false,
					Digest:     l.Digest,
					Image:      repo.String(),
					Tag:        tag,
				})
			}
		}
	}

	for _, r := range out {
		b, err := json.Marshal(r)
		if err != nil {
			return fmt.Errorf("error creating json: %w", err)
		}
		fmt.Printf("%s\n", string(b))
	}

	/*
		for digest, manifest := range tags.Manifests {
			fmt.Printf("%s@%s\n", repo, digest)

			for _, tag := range manifest.Tags {
				fmt.Printf("%s:%s\n", repo, tag)
			}
		}
	*/
	return nil
}

type Row struct {
	IsManifest bool   `json:"is_manifest"`
	Digest     string `json:"digest"`
	Image      string `json:"image"`
	Tag        string `json:"tag"`
}

type DockerManifest struct {
	Config Layer   `json:"config"`
	Layers []Layer `json:"layers"`
}

type Layer struct {
	MediaType string `json:"mediaType"`
	Size      int64  `json:"size"`
	Digest    string `json:"digest"`
}

type Root struct {
	Child []string `json:"child"`
}
