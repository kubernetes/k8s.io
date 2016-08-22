# Running Reviewable Enterprise on Kubernetes

[Reviewable.io](https://reviewable.io) is a popular code-review tool that
integrates deeply with GitHub.  For those organizations that can't use the
hosted product, they offer an [enterprise
edition](https://github.com/Reviewable/Reviewable/tree/master/enterprise) which
you can run yourself.  This repository covers how to run it on Kubernetes.

## Basics

You should start with [Reviewable's
docs](https://github.com/Reviewable/Reviewable/blob/master/enterprise/config.md),
which detail how to run Reviewable Enterprise.  This will give you an idea of
the major pieces of the system and will walk you through setting up the various
dependencies.

In addition to this, you should procure an SSL certificate for your site.

## Namespace

For cleanliness we assume that this whole installation is done in a clean
[Namespace](http://kubernetes.io/docs/user-guide/namespaces/).  This doc will
not prescribe a Namespace name, but every API object we use should be in the
same Namespace.

You can create a new namespace with `kubectl create namespace my-reviewable`, or
by running `kubectl apply -f <file>` against a file holding the following YAML:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-reviewable
```

## Configuration

We're going to use Kubernetes
[ConfigMaps](http://kubernetes.io/docs/user-guide/configmap/) to hold the
various configurable parameters that Reviewable needs and
[Secrets](http://kubernetes.io/docs/user-guide/secrets/) to hold the various
credentials. The Reviewable docs sort of mix the two together, but Kubernetes
makes a distinction, so let's use that.

Reviewable wants its parameters as environment variables (it also supports a
config file, but that happened after I started writing this).  ConfigMaps and
Secrets both support "projecting" values into environment variables.  This will
be the primary way we configure the system.  Once you have these files
configured, you can load them into Kubernetes with `kubectl apply -f <file>` for
each file.

Below you will find the YAML for the ConfigMap, with comments.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: reviewable
data:
  meta-config-version: "1"  # This is our own version number
  reviewable-host-url: <your site's URL, e.g. https://reviewable.kubernetes.io>
  port: "80"  # What port number should reviewable run on
  #reviewable-github-url: # non-specified means to use public github
  reviewable-code-executor: sandcastle  # Run user-provided code in Sandcastle
  gae-vm: "true"  # Reviewable should offer Google AppEngine-compatible features
```

There are several other keys that may be needed in different situations.  Follow
[Reviewable's config
docs](https://github.com/Reviewable/Reviewable/blob/master/enterprise/config.md)
and the pattern established here to add more.

One thing worth noting here is the syntax of the keys.  Reviewable wants env
vars like `REVIEWABLE_LICENSE`, but as of Kubernetes v1.3.x ConfigMaps and
Secrets have a very limited set of allowed character in keys.  Specifically
upper-case letters and underscores are not allowed.  This restriction is lifted
in Kubernetes v1.4.  In the mean time, we have to manually map key names to env
var names (in the Deployment config).

For easier comprehension, we are going to break the Secrets up into a number of
files, each grouped around a single purpose.  This is totally artificial, and
you can re-group these or put them all in one Secret, if you like.

Reviewable license:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: license
data:
  reviewable-license: <REDACTED>
```

Firebase:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: firebase
data:
  reviewable-firebase: <REDACTED>
  reviewable-firebase-auth: <REDACTED>
  reviewable-encryption-private-keys: <REDACTED>
```

GitHub OAuth:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: github-oauth
data:
  reviewable-github-client-id: <REDACTED>
  reviewable-github-client-secret: <REDACTED>
```

GitHub webhook:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: github-webhook
data:
  reviewable-github-secret-token: <REDACTED>
```

Sentry:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: sentry
data:
  reviewable-server-sentry-dsn: <REDACTED>
  reviewable-client-sentry-dsn: <REDACTED>
```

SSL:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ssl
type: kubernetes.io/tls
data:
  tls.crt: <REDACTED>
  tls.key: <REDACTED>
```

## Service & Ingress

Next we will create a Kubernetes
[Service](http://kubernetes.io/docs/user-guide/services/) to front our instance
of Kubernetes.  We haven't actually run the instance yet, but that is OK.
Kubernetes is able to bring up the Service with no backends, and it can even use
that as a scheduling hint to spread Pods across Nodes.

As with other YAML files, `kubectl apply -f <file>` this:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: reviewable
spec:
  selector:
    app: reviewable  # Take note of this: make sure your Deployment matches!
  type: NodePort     # This is for Ingress to use
  ports:
    - name: http
      port: 80       # Configurable, but why bother?
```

If you choose to change the `port` key in the ConfigMap, you should either
change the Service `port` or add a `targetPort` line that is the same as the
ConfigMap `port`.  This allows the Service to access the Reviewable instance(s).

Reviewable does not handle SSL itself.  It expects to have an HTTP proxy between
the user and the Reviewable instance.  Kubernetes Services are a layer-4
concept, but we need layer-7.  Fortunately, Kubernetes has
[Ingress](http://kubernetes.io/docs/user-guide/ingress/) to handle that.  The
following YAML sets up a very simple L7 proxy that handles SSL and forwards
traffic to your Reviewable instance(s).  As before, `kubectl apply -f <file>`.

```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: reviewable
  annotations:
    kubernetes.io/ingress.global-static-ip-name: reviewable-k8s-io  # on GCE
spec:
  tls:
    - secretName: ssl  # must match the Secret configured above
  backend:
    # By default, all URLs end up here.
    serviceName: reviewable  # must match the Service configured above
    servicePort: http        # must match the Service configured above
  rules:
    - http:
        paths:
          - path: /_ah       # special-case this prefix back to /
            backend:
              serviceName: reviewable
              servicePort: http
```

This uses an annotation that may not work on all cloud providers:
`kubernetes.io/ingress.global-static-ip-name`.  This tells Ingress to use a
specific managed IP address for incoming traffic.  This makes DNS management
simpler, but isnt required.  Without this Ingress will get an IP allocated to
it.  In either case, you can point DNS for your Reviewable site at the IP that
this Ingress object uses (`kubectl get ingresses`).

This cross-references the SSL Secret by name, which feeds the SSL certificate to
the HTTP proxy.  Now your site is SSL-enabled.

## Deployment

The last step in this process is to actually run the Reviewable binary.  The
nice folks at Reviewable publish their program as a Docker image.  This image is
in a private GitHub repo, so you'll need credentials to pull it.  We manifest
this as one last Secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: docker-pull
type: kubernetes.io/dockercfg
data:
  .dockercfg: <REDACTED>
```

You can create this Secret with the `create secret docker-registry` command, too.

Take a breath - the moment of truth is upon you.  Let's run Reviewable.  The
following YAML is the
[Deployment](http://kubernetes.io/docs/user-guide/deployments/) configuration
you need.

```yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: reviewable
  labels:
    app: reviewable
    version: v1
spec:
  replicas: 2  # set this to the value that works for you.
  # selector defaults to template's labels
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app: reviewable  # note that this matches the Service selector
        version: v1
    spec:
      terminationGracePeriodSeconds: 30
      imagePullSecrets:
        - name: docker-pull  # must match the Secret above
      containers:
        - name: reviewable
          image: reviewable/enterprise:1158.1885
          resources:
            limits:
              cpu: 1
              memory: 2Gi
          ports:
            - name: http
              containerPort: 80  # must match the ConfigMap port value
          livenessProbe:
            httpGet:
              path: /_ah/health
              port: 80
            initialDelaySeconds: 15
            timeoutSeconds: 5
            failureThreshold: 3
          lifecycle:
            preStop:
              httpGet:
                path: /_ah/stop
                port: 80
          env:
            - name: REVIEWABLE_LICENSE
              valueFrom:
                secretKeyRef:
                  name: license
                  key: reviewable-license
            - name: REVIEWABLE_HOST_URL
              valueFrom:
                configMapKeyRef:
                  name: reviewable
                  key: reviewable-host-url
            - name: META_CONFIG_VERSION
              valueFrom:
                configMapKeyRef:
                  name: reviewable
                  key: meta-config-version
            - name: PORT
              valueFrom:
                configMapKeyRef:
                  name: reviewable
                  key: port
            - name: REVIEWABLE_GITHUB_CLIENT_ID
              valueFrom:
                secretKeyRef:
                  name: github-oauth
                  key: reviewable-github-client-id
            - name: REVIEWABLE_GITHUB_CLIENT_SECRET
              valueFrom:
                secretKeyRef:
                  name: github-oauth
                  key: reviewable-github-client-secret
            - name: REVIEWABLE_FIREBASE
              valueFrom:
                secretKeyRef:
                  name: firebase
                  key: reviewable-firebase
            - name: REVIEWABLE_FIREBASE_AUTH
              valueFrom:
                secretKeyRef:
                  name: firebase
                  key: reviewable-firebase-auth
            - name: REVIEWABLE_ENCRYPTION_PRIVATE_KEYS
              valueFrom:
                secretKeyRef:
                  name: firebase
                  key: reviewable-encryption-private-keys
            #- name: REVIEWABLE_GITHUB_URL
            #  valueFrom:
            #    configMapKeyRef:
            #      name: reviewable
            #      key: reviewable-github-url
            - name: REVIEWABLE_GITHUB_SECRET_TOKEN
              valueFrom:
                secretKeyRef:
                  name: github-webhook
                  key: reviewable-github-secret-token
            - name: REVIEWABLE_SERVER_SENTRY_DSN
              valueFrom:
                secretKeyRef:
                  name: sentry
                  key: reviewable-server-sentry-dsn
            - name: REVIEWABLE_CLIENT_SENTRY_DSN
              valueFrom:
                secretKeyRef:
                  name: sentry
                  key: reviewable-client-sentry-dsn
            - name: REVIEWABLE_CODE_EXECUTOR
              valueFrom:
                configMapKeyRef:
                  name: reviewable
                  key: reviewable-code-executor
            - name: GAE_VM
              valueFrom:
                configMapKeyRef:
                  name: reviewable
                  key: gae-vm
```

This is a little lengthy, but you can see that it just runs a single container.
That container is health-checked and restarted if it is not happy.  The most
important section is the `env` block.  It maps each ConfigMap and Secret key to
an environment variable, following Reviewable's docs.

After you `kubectl apply -f <file>` this, Kubernetes will spin up however many
replicas you asked for.  Once those replicas are running, they will be added to
the Service's Endpoints list.  The Ingress is ready to route to the Service, and
DNS is pointing at the Ingress.  Your Reviewable site should be up.  If anything
went wrong, start by looking at the logs for the Pods created by this
Deployment.

## Now what?

Now you can use Reviewable.  There's still work to do to really "productionize"
this site.  You probably want to collect the logs and monitor the site.  These
are very specific to your own installation, so we leave them as an exercise for
the reader.

In addition to that, there may be other configuration params you want to set on
Reviewable.  We can't hope to cover every parameter, and Reviewable is always
getting better and adding new capabilities.  Hopefully this doc lays out some
reusable patterns and shows you how to continue running your Reviewable
instance.
