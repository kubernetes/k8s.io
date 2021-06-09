- [Deploying a proxy cache](#orgbb53de3)
  - [Distribution](#orgd81e913)
    - [Deploy with Docker](#org60ed8ed)
    - [Deploy with Kubernetes](#orga5b4e37)
  - [Harbor](#org78cd2b7)
    - [Deploy with the installer](#org3d65f37)
    - [Deploy with Helm in Kubernetes](#org799aae7)
- [Deploy](#org00fe5d5)
  - [Kubeadm](#org4ccdca0)
  - [Kops](#org7ea6b4d)
  - [ClusterAPI](#org3f249a6)

Hosting your own copies of Kubernetes images is a sustainable way to give back to the Kubernetes community. By setting up a transparent proxy cache, images will be pulled from you closer OCI compatible cache and then from _k8s.gcr.io_.

<a id="orgbb53de3"></a>

# Deploying a proxy cache

Here are two OCI compatible container registries that you can bring up to host container images.

<a id="orgd81e913"></a>

## Distribution

Define the config

```yaml
version: 0.1
log:
  accesslog:
    disabled: true
  level: debug
  fields:
    service: registry
    environment: development
auth:
  htpasswd:
    realm: basic-realm
    path: /etc/docker/registry/htpasswd
storage:
  delete:
    enabled: true
  filesystem:
    rootdirectory: /var/lib/registry
  maintenance:
    uploadpurging:
      enabled: false
http:
  addr: :5000
  secret: registry-k8s-io-registry-k8s-io
  debug:
    addr: :5001
    prometheus:
      enabled: true
      path: /metrics
    headers:
      X-Content-Type-Options: [nosniff]
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
proxy:
  remoteurl: https://k8s.gcr.io
```

<a id="org60ed8ed"></a>

### Deploy with Docker

```shell
USERNAME=distribution
PASSWORD=Distritest1234!
htpasswd -Bbn $USERNAME $PASSWORD > /tmp/htpasswd
```

```shell
docker run -d \
    -p 5000:5000 \
    -v /tmp/htpasswd:/etc/docker/registry/htpasswd \
    -v /tmp/config.yml:/etc/docker/registry/config.yml \
    --restart always \
    --name registry-proxy-cache \
    registry:2.7.1
```

```shell
docker rm -f registry-proxy-cache
```

<a id="orga5b4e37"></a>

### Deploy with Kubernetes

Create the namespace

```shell
kubectl create ns distribution
```

Create the config

```shell
kubectl -n distribution create configmap distribution-config --from-file=config\.yml=distribution-config.yaml --dry-run=client -o yaml | kubectl apply -f -
```

Create the auth secret

```shell
USERNAME=distribution
PASSWORD=Distritest1234!
kubectl -n distribution create secret generic distribution-auth --from-literal=htpasswd="$(htpasswd -Bbn $USERNAME $PASSWORD)"
```

Define the deployment

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: distribution
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: distribution-data
  namespace: distribution
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: distribution
  namespace: distribution
spec:
  replicas: 1
  selector:
    matchLabels:
      app: distribution
  template:
    metadata:
      labels:
        app: distribution
    spec:
      containers:
        - name: distribution
          image: registry:2.7.1
          imagePullPolicy: IfNotPresent
          resources:
            limits:
              cpu: 10m
              memory: 30Mi
            requests:
              cpu: 10m
              memory: 30Mi
          ports:
            - containerPort: 5000
          env:
            - name: TZ
              value: "Pacific/Auckland"
          volumeMounts:
            - name: distribution-data
              mountPath: /var/lib/registry
            - name: distribution-config
              mountPath: /etc/docker/registry/config.yml
              subPath: config.yml
            - name: distribution-auth
              mountPath: /etc/docker/registry/htpasswd
              subPath: htpasswd
          readinessProbe:
            tcpSocket:
              port: 5000
            initialDelaySeconds: 2
            periodSeconds: 10
          livenessProbe:
            tcpSocket:
              port: 5000
            initialDelaySeconds: 1
            periodSeconds: 20
      volumes:
        - name: distribution-data
          persistentVolumeClaim:
            claimName: distribution-data
        - name: distribution-config
          configMap:
            name: distribution-config
        - name: distribution-auth
          secret:
            secretName: distribution-auth
---
apiVersion: v1
kind: Service
metadata:
  name: distribution
  namespace: distribution
spec:
  ports:
    - port: 5000
      targetPort: 5000
  selector:
    app: distribution
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: distribution
  namespace: distribution
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
spec:
  tls:
    - hosts:
        - my-registry.mirror.host
      secretName: letsencrypt-prod
  rules:
    - host: my-registry.mirror.host
      http:
        paths:
          - path: /
            pathType: ImplementationSpecific
            backend:
              service:
                name: distribution
                port:
                  number: 5000
```

Install distribution

```shell
kubectl apply -f distribution.yaml
```

<a id="org78cd2b7"></a>

## Harbor

<a id="org3d65f37"></a>

### Deploy with the installer

<https://goharbor.io/docs/2.2.0/install-config/download-installer/>

<a id="org799aae7"></a>

### Deploy with Helm in Kubernetes

<https://goharbor.io/docs/2.2.0/install-config/harbor-ha-helm/>

<a id="org00fe5d5"></a>

# Deploy

<a id="org4ccdca0"></a>

## Kubeadm

```shell
kubeadm init --image-repository="my-registry.mirror.host"
```

<a id="org7ea6b4d"></a>

## Kops

<https://kops.sigs.k8s.io/cluster_spec/#registry-mirrors> <https://kops.sigs.k8s.io/cluster_spec/#containerproxy>

```yaml
spec:
  assets:
    containerProxy: my-registry.mirror.host
```

<a id="org3f249a6"></a>

## ClusterAPI

Requires v1alpha4 <https://github.com/kubernetes-sigs/cluster-api/blob/af33e43/bootstrap/kubeadm/api/v1alpha4/kubeadm_types.go#L115-L120>
