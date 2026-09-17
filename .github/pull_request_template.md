**What this PR does / why we need it**:

**Special notes for your reviewer**:

**If you are promoting an image, please make sure you have done the following:**

- [ ] I have verified the digest with [gcrane](https://github.com/google/go-containerregistry/blob/main/cmd/gcrane/README.md) and added it as a comment to the PR or in the body.

- [ ] I'm promoting a multi-arch image that matches all the [supported](https://github.com/kubernetes/sig-release/tree/master/release-engineering/platforms) platforms of Kubernetes.

- [ ] I'm not promoting a tag that resolves to latest or moving tags as these are not supported

- [ ] registry.k8s.io is an immutable registry and I'll need to cut a new release if the digest is wrong.
