# infra/gcp

Scripts and configuration files related to the management of the Kubernetes
project's GCP infrastructure

## layout

Loosely organized as follows:
- `bash/` to manage the bulk of our infrastructure (this came first)
- `static/` static files deployed directly to our infrastructure
- `terraform/` for managing the rest of our infrastructure

The bash came first, and the terraform is slowly growing as our comfort with it
grows. The decisions that led to some bash being in subdirectories were ad-hoc
or seemed like good ideas at the time; consider them undocumented and open to
reconsideration.

A more detailed listing thanks to `tree`, with some files manually elided:
```
.
├── bash
│   ├── ensure-{foo}.sh     # entrypoints for managing the set of foo infrastructure
│   ├── infra.yaml          # config for ensure-* scripts
│   ├── lib.sh              # included by all ensure-* scripts
│   ├── lib_{foo}.sh        # reusable bash functions for GCP service foo
│   ├── backup_tools        # TODO: bash related to prod artifact hosting
│   ├── cip-auditor         # TODO: bash related to prod artifact hosting
│   ├── namespaces          # bash to manage namespaces / rbac for cluster: aaa
│   ├── prow                # bash to manage k8s-infra-e2e* projects and prow secrets
│   └── roles               # bash and yaml to manage custom GCP IAM roles
├── static          # content related to prod artifact hosting
└── terraform
    ├── {foo}               # terraform managing resources in project foo
    │   └── {bar}/resources # k8s resources deployed to GKE cluster {bar}
    └── modules             # modules for re-use within this repo
```

## bash

### deploying changes

The bash in here needs to be manually run by humans. At the moment, this is
usually restricted to members of k8s-infra-gcp-org-admins@kubernetes.io

### principles

- scope scripts appropriately
  - each `ensure-*.sh` script should manage a set of resources such that
    less-privileged-than-org-admin roles could run these scripts
  - each `lib_*.sh` script should contain functions that are generically
    reusable for a GCP service; consider these equivalent to terraform
    resources rather than richer terraform modules
  - only `ensure-*.sh` scripts should be executable, lib_*.sh
- use functions
  - use a `main` entrypoint at the bottom of the script to invoke functions
    defined above
  - easier to reuse other functions (vs. relying on order of definition)
- name functions consistently
  - use `ensure_[removed_]_{resource}` for creation of resources
  - older scripts use `empower_foo` for common/convenience IAM changes (e.g.
    multiple `ensure_foo_iam_binding` calls for a well-known group)
- define functions in the appropriate files
  - `ensure-*.sh` if they are domain-specific
  - `lib_foo.sh` if they are generic/reusable for GCP service Foo
  - `lib.sh` if they are domain-specific and need to be used by more than one
    ensure-*.sh script
- follow function arg conventions
  - write functions such that they can operate on a list of args, e.g.
    `enable_services foo bar baz`
  - use arrays more often, and pass those arrays as lists of args
    - arrays can support multi-line definitions of lists with comments, such
      as for complicated command line invocations
    - arrays can be dynamically modified or generated, e.g. dynamically adding
      a flag based on other configuration
- use constants or config instead of hardcodes
  - if the constant is domain-specific, keep it within the ensure-*.sh script
  - if the constant is needed across multiple ensure-*.sh scripts, put it in
    lib.sh, preferably sourced from infra.yaml
- keep output meaningful
  - when changing the configuration of an existing resource, output from the
    underlying tool is often unhelpful, like "changed foo"
  - prefer generating output that shows a diff of what changed, see the way
    IAM changes are displayed in lib_iam.sh for exampe
  - logging should generally happen at the ensure-*.sh script level instead
    of lower down in lib_*.sh functions
  - use the `foo 2>&1 | indent` pattern to indent all output from `foo`

## infra.yaml

To aid in transitioning away from bash, we are moving some of the config for
our infrastructure into a file (potentially a hierarchical set of files) called
`infra.yaml`.  At present it is only read by some bash, and its schema is an
unvalidated work in progress.

The schema is roughly as follows:
```yaml
infra:
  {project_type}: # ideally this ~= folder
    [managed_by:] # default script/file used to manage projects
    projects:
      {project_id}:
        [managed_by:] overrides default; script used to manage _this_ projec
```

Please refer to [`infra.yaml`](/infra/gcp/infra.yaml) to see which `ensure-*.sh`
scripts or terraform modules are responsible for which GCP projects

## terraform

See [infra/gcp/terraform/README.md](/infra/gcp/terraform/README.md)
