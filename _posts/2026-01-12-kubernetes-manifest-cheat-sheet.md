---
layout: post
title: Kubernetes Manifest Cheat Sheet
date: 2026-01-12 10:18 -0500
categories: [Kubernetes]
tags: [kubernetes, manifests, yaml, k8s]
---

YAML, or "YAML Ain't Markup Language" (seriously, that's the acronym, similar to GNU's Not Unix huh?), is an interesting data serialization language. It's not nearly as pedantic as XML, but is interchangeable with JSON. The big draw of YAML though is its readability. Compare these extremely contrived examples that _all represent the same thing_.

## YAML vs XML vs JSON

This is just XML data that has nothing to do with Kubernetes, just an example:

```xml
<server>
  <name>alpha</name>
  <environment>production</environment>
  <ip>10.0.0.42</ip>

  <tags>
    <tag>web</tag>
    <tag>api</tag>
  </tags>

  <services>
    <nginx>
      <port>80</port>
      <ssl>false</ssl>
    </nginx>
    <redis>
      <port>6379</port>
      <persistent>true</persistent>
    </redis>
  </services>
</server>
```

XML also has parameters in the tags that I can use, but for the whole interchangeability example I won't use it here. So for example, you could add something like `<ip version="4">10.0.0.42</ip>` into your data as well.

Now compare XML to something like JSON:

```json
{
  "server": {
    "name": "alpha",
    "environment": "production",
    "ip": "10.0.0.42",
    "tags": ["web", "api"],
    "services": {
      "nginx": {
        "port": 80,
        "ssl": false
      },
      "redis": {
        "port": 6379,
        "persistent": true
      }
    }
  }
}
```

Which in my opinion is a bit easier to work with. In this "prettified" version of JSON that's properly tabbed out, it seems easy to grasp. In fact my first thought about JSON is that it's kinda Python-like. It's represented pretty nicely as a dictionary object that contains subsets of other dictionaries, lists, etc. But in most cases when we're dealing with inter-process communication, you generally won't see the pretty version. You'll see something more akin to this:

```json
{"server":{"name":"alpha","environment":"production","ip":"10.0.0.42","tags":["web","api"],"services":{"nginx":{"port":80,"ssl":false},"redis":{"port":6379,"persistent":true}}}}
```

See, spaces don't affect JSON, so for the sake of efficiency, this is what it looks like when you're dealing with a JSON object. Fine for IPC, not so fine for readability. At this point you'd need to send this through a JSON prettify application to get it to look more like the above.

YAML, on the other hand, is designed to actually look easy to manipulate.

```yaml
server:
  name: alpha
  environment: production
  ip: 10.0.0.42
  tags:
    - web
    - api
  services:
    nginx:
      port: 80
      ssl: false
    redis:
      port: 6379
      persistent: true
```

It's almost as if it looks like a config file, like a .ini file or something. And that's why kubernetes uses yaml files for manifests. One of the first things I hated about YAML was just how picky it was with the spacing. You have to use two spaces for indents and specific things _need_ to be indented. Nowadays it makes sense but when I was just learning how to work with yaml files, that became the most annoying bit.

Now YAML in general is just serialized data that any application can ingest into a workable object. The above example is mostly nonsense unless an application can use it. Kubernetes expects your YAML files to follow a specific pattern, and it expects certain data to be there. If you add anything else, K8s will happily add it to the manifest, but it will only use the data that it uses. More info on that later.

## Kubernetes Manifest Basics

_Most_ Kubernetes manifests will have the same 5 roots to each object:

```yaml
apiVersion: <What part of the K8s API will use this manifest>
kind: <What kind of Manifest this is>
metadata:
  # This is any metadata about this particular manifest.
  # The name of this service will be here, what namespace it will run in,
  # any labels, annotations, etc. More info later.
  name: MyThingie
  namespace: default
  labels:
    my_thingie: blahblahblah

spec:
  # This is the meat of the manifest. Anything that tells how this manifest
  # should run will go under here. If this is a pod, then you will explain
  # what image it should use, how many replicas in a deployment, what
  # template it should use when starting pods, etc.

data:
  # Used mostly for objects that hold data only, like secrets or configmaps.
  # This would be used in place of spec. Also you can use stringData, more
  # on that later.

status:
  # If you are writing the manifest, you will never add this root level data object.
  # The cluster itself adds this as a means of putting status messages for the running
  # object, so you can use "kubectl describe" to output the content of this.
```

> When you create a manifest, you need at least `apiVersion`, `kind`, and `metadata`. The `spec` section is typically there, but not for things like configmaps and secrets, where `data` replaces it. Also, manifests are case sensitive, so make sure everything is lowercase, and typically the "kind" is CamelCase. So a `ReplicaSet` is different from a `replicaset`. Something to keep in mind!
{: .prompt-warning }

> Anything in double-quotes is considered a string, so if you are passing a numeric value or boolean, don't encapsulate in quotes. However, it takes some liberties in anything you type so you don't really need quotes for all that much as it will imply that something is a string if it's clearly alphanumeric. By using double-quotes you are outwardly specifying that it is a string, such as passing the value "100" as a string instead of a number. Just a thought.
{: .prompt-tip }

- The `apiVersion` section will specify what resource endpoint inside of the Kubernetes API will handle this particular manifest. When you install specific applications that come with their own CRD (Custom Resource Definitions), they will install definitions inside of the kubernetes cluster itself which will allow you to send manifests to the specific component. If you install cert-manager or metal-lb as an example, they will have their own `apiVersion` specification to submit manifests to these services.

- The `kind` section just specifies what this particular manifest is. The basic K8s objects are Services, Deployments, Pods, Replicasets, etc etc -- but these could be their own types specific to whatever `apiVersion` section you're referencing here.

- `metadata` is used to add data specific to the manifest itself. The name of the service goes here, the namespace that exists here. Any labels you put in here that kubernetes can use to group objects together, so you can specify a selector which references the following k8s objects with specific labels you specify. You can pretty much add whatever you want here, as K8s will either use it or not, though K8s will expect certain things to be here anyway, such as the name.

- The `spec` section is where you specify what the manifest actually does. This can get large depending on what it is you're adding, or non-existant in some really simple objects.

- The `data` section is unique to objects in kubernetes that just hold data, like configmaps or secrets.

- Finally, `status` is added and filled in by the kubernetes cluster. You don't need to add this section.

## Example Manifests

Here are examples I've used for specific kubernetes objects.

### Namespace

First of all, as a quick shortcut, I use this command to create a namespace:

```terminal
$ kubectl create ns my-namespace
```

Or, I can create a declarative file, and I can pretty much do this for most objects:

```terminal
$ kubectl create ns my-namespace --dry-run=client -o yaml > namespace.yaml
```

It creates a namespace manifest for me, though it adds some data that isn't really useful. Anyway, here's an example of a namespace manifest:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-namespace
```

Quick and simple.

### Deployment

Similarly to the above, you can create a boilerplate manifest using the `dry-run` trick earlier for a deployment, just give it a name, an image to start with, how many replicas, etc:

```terminal
$ kubectl create deploy my-deployment --image=ghcr.io/agr0dan/mycontainer:v1 --replicas=1 --dry-run=client -o yaml > deployment.yaml
```

I almost always will create a deployment rather than a pod or a replicaset. This does all the heavy lifting of handling those more granular objects. The reasoning behind that is that a pod is the most atomic manifest, just defining a container running somewhere in the cluster. The next stage up being the replicaset defining a pod but also telling it how many copies it should be running, and finally the deployment doing everything the replicaset does, _but also_ defining the upgrade strategy, so if you want to use the next version of an image it would roll out the image version slowly to minimize downtime as much as possible. The bottom line here is that a deployment is typically what you'd want to create in most cases.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-deployment
  namespace: my-namespace
  labels:
    my.deployment.app: dansapp
spec:
  replicas: 5           # run 5 copies of the below container
  strategy:
    type: RollingUpdate # This is default, but you can choose how applications
                        # will update. RollingUpdate means that if you update
                        # this manifest with a new version of a container, it
                        # will start up a new container, then shut down an
                        # old one, and repeat until all are replaced.

  selector:
    matchLabels:
      app: dansapp      # This must match a label of the pod mentioned in the
                        # "template" below
  
  template:             # This is the pod that will run from this deployment.
                        # Note that besides the 'apiVersion' root item, this
                        # follows the same spec sheet as any other k8s service
    metadata:
      labels:
        app: dansapp    # This should match what you add in the selector above!
      annotations:
        any.annotation: here   # annotations are usually passed to the
                               # application as a means of configuring it from
                               # the manifest itself
    spec:
      serviceAccountName: my-svc-acct
      automountServiceAccountToken: true
      containers:       # Note, "containers", plural -- you can add more than
                        # one but you'll usually only add one
        - name: my-app
          image: "ghcr.io/agr0dan/myapp:v1"
          imagePullPolicy: "Always" # Don't use cached images, always get latest
          env:          # Any env variables that should run with the container?
            - name: my_env_var
              value: "My environment variable value"
            - name: another_env_var
              value: "Another environment variable value"
            - name: SECRET_PASSWORD
              valueFrom:
                secretKeyRef:   # Pull an environment variable from a k8s secret
                  name: my-secret-password # Set the variable name inside container
                  key: SECRET_PASSWORD     # This is the value in the k8s secret
                                           # that holds the sensitive value

            - name: SOME_CONFIG # You can also do the same from a configmap
              valueFrom:
                configMapRef:
                  name: my-config
                  key: config-val
          
          envFrom:      # OR, if you have a bunch of environment variables in a
                        # configmap or secret, you can just store a bunch of them
                        # in one giant configmap and load them all here like so
            - configMapRef:
                name: my-config-map
            - secretRef:
                name: my-secret

          ports:
            - name: http
              containerPort: 3000 # the exposed port on the container
              protocol: TCP
          
          volumeMounts:
            - mountPath: /app/config/app.conf # Where to mount in container
              name: app-config                # The name of the volume listed below
              subPath: app.conf               # The section in the configmap that
                                              # contains the contents of this file
            - mountPath: /app/config/logs
              name: logs
            - mountPath: /app/config/data
              name: data
            - mountPath: /etc/secret
              name: my-secret-file
              readOnly: true
      
      volumes:                               # Here I'll specify all the volumes
                                             # referenced in the above container(s)
        - name: app-config
          configMap:
            name: my-app-config             # The name of the configmap I'm pulling
                                            # this from, inside this should be a file
                                            # called "app.conf"
        - name: logs
          emptyDir: {}                      # This is a special volume that will be
                                            # deleted on restart
        - name: data
          persistentVolumeClaim:
            claimName: my-pvc
        - name: my-secret-file
          secret:
            secretName: my-secret
```

The above is a giant example that has a lot of moving parts. In most cases, you probably won't need as many environment variables, mount points, etc -- this all depends on the application in question. Regardless, sometimes when I want to design a deployment in my cluster, I can use this as a reference to get things set up.

### Certificate for Cert-Manager

If I want to generate a new cert, such as a wildcard cert, I will use this template:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: mycert.agrohacksstuff.io
  namespace: traefik
spec:
  privateKey:
    rotationPolicy: Always
  secretName: mycert.agrohacksstuff.io
  dnsNames:
    - *.agrohacksstuff.io
    - agrohacksstuff.io
  issuerRef:
    name: <name of my issuer I set up, probably letsencrypt-prod>
    kind: ClusterIssuer     # Assuming the issuer is a cluster issuer
    group: cert-manager.io  # <-- THIS is important for cert-manager >=1.19!
```

In most cases I won't need a new certificate, as I'll just create the one wildcard. But you do what you want.

### Persistent Volume Claim

Need persistent storage? Set up a PVC!

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
  namespace: my-namespace
spec:
  accessModes:
    - ReadWriteOnce   # Note that only one container can attach this! ReadWriteMany
                      # to allow shared data
  resources:
    requests:
      storage: 5Gi
  storageClassName: synology-iscsi-storage # or whatever storage class you have
                                           # unless you just want the default
```

### Service (ClusterIP)

Use this to create a service that attaches to a deployment/replicaset. This will create a single IP inside of the cluster that is accessible ONLY from inside the cluster. To make it accessible from the outside, you'd either create a NodePort or LoadBalancer type, or you'd create an Ingress or HTTPRoute to route through an application proxy.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
  namespace: my-namespace
spec:
  type: ClusterIP      # This is unnecessary as ClusterIP is the default
                       # service, but I'm pedantic
  selector:
    app: dansapp       # This is the label specified in a deployment's
                       # template container
  ports:
    - protocol: TCP
      port: 3000       # The port on the service
      targetPort: 3000 # The port on the endpoint container
```

### Service (LoadBalancer)

Assuming you have something that handles load balancing, this is a manifest that specifies an IP. Otherwise it relies on DHCP or something.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service-lb
  namespace: my-namespace
spec:
  type: LoadBalancer
  loadBalancerIP: 192.168.1.50
  selector:
    app: dansapp
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

### ConfigMap

Two examples, one where I'll just have keys and values, and another that will have full files included.

#### Keys: Values

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-config-map
  namespace: my-namespace
  labels:
    vars: myvars # arbitrary and probably unnecessary
data:
  SOME_ENVIRONMENT_VARIABLE: "my value"
  foo: "bar"
```

#### File contents

This can be mounted as a volume and thus mounted as a single file in the container that mounts it. Pretty handy.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-config-data
  namespace: my-namespace
data:
  myfile.txt: |
    here is some data to put in my file!
    and here is another line!
  anotherfile.txt: |
    here is another file with additional data, wow!
```

The `|` character specifies a multi-line entry in YAML.
> NOTE: Configmaps are _only_ accessible inside of the namespace they exist in. Another application cannot access a configmap if it is in another namespace altogether!
{: .prompt-info }

### Secrets

When you specify a secret as a manifest, in most cases you have to encode it in base64. This is basically so you can put any kind of binary blob in there and it will store it as a secret, but even for passwords and other sensitive strings? I think that's kinda dumb because, say it with me now, ***BASE64 IS NOT ENCRYPTION, IT IS ENCODING, AND CAN BE DECODED BY ANYONE.*** Now that that's out of the way...

For this example, I'll encode `Sup3r-s3cr3t-d4t4` as a password, which encodes to `U3VwM3ItczNjcjN0LWQ0dDQ=`. To do that, I'll run:

```terminal
$ echo -n 'Sup3r-s3cr3t-d4t4' | base64
U3VwM3ItczNjcjN0LWQ0dDQ=
```

Note the use of the `-n` flag, which ensures that no trailing newline character is _also_ included in the encoded data.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
  namespace: my-namespace
type: Opaque
data:
  my_password: U3VwM3ItczNjcjN0LWQ0dDQ=
```
> NOTE: Just like configmaps, secrets are only accessible from inside the namespace they exist in.
{: .prompt-info }

The type here is `Opaque`, which is the default type of secret and you don't have to specify that it's Opaque. That's just arbitrary data. But you can store specific types of data in a secret, like docker configs, SSH keys, basic auth, and TLS certs, among others. Most of the time Opaque will do the job just fine. You can add data just like the Configmap object above, storing files on multiple lines here as well.

Also, you don't _have_ to encode your data to base64. You can just use `stringData` as a type and you won't have to encode any of your data:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
  namespace: my-namespace
stringData:
  my_secret_var: blahblahblah
```

### Ingress

For my ingress I'll just use traefik as the example. Also I have my wildcard cert running in my Traefik namespace, and I configured Traefik to set that as the default certificate. Knowing that, this is the general ingress I'll use for `example.agrohacksstuff.io`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-web-ingress
  namespace: my-namespace
  annotations:        # This is passed to Traefik itself to work with
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  rules:
  - host: example.agrohacksstuff.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web        # Name of the service you created for this
            port:
              number: 3000   # The port open on the service
```

Otherwise, I can also use my own certificate just for this subdomain:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-web-ingress
  namespace: my-namespace
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: "web,websecure" 
                          # Note, port 80 and 443 == web and websecure
spec:
  ingressClassName: "traefik"
  tls:
  - hosts:
    - example.agrohacksstuff.io
    secretName: example.agrohacksstuff.io # Or however my tls cert is stored
  rules:
  - host: example.agrohacksstuff.io
    http:
      paths:
        - pathType: Prefix
          path: /
          backend:
            service:
              name: web # name of the service you created for this
              port:
                number: 3000 # Port open on the service
```

### GatewayClass

This is another implementation of an Ingress, this allows you to be a bit more agnostic when it comes to what software you'd use as the application proxy, because you'd be defining HTTP routes rather than an ingress with specific annotations that the application proxy will understand. It's a bit more wordy, but it's the most logical way to do this, I think.

This defines the controller I'll use. In this case, I'm using Traefik as the gateway controller. And no, using the Gateway API is _not_ an alternative to using an application proxy and instead using Kubernetes' built-in methods, this is a better way of implementing ingresses. I will still have to use Traefik here.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: traefik # or whatever your application proxy is
spec:
  controllerName: traefik.io/gateway-controller
```

### Gateway

In the case of the whole Gateway API architecture here, the `Gateway` itself is what defines the door, so to speak. The gateway class specifies what _kind_ of door I'm dealing with, this now defines specifically that traefik will be the door I'll use. I'll run this inside of Traefik's namespace.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: traefik-gateway
  namespace: traefik
spec:
  gatewayClassName: traefik
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All

    - name: websecure
      protocol: HTTPS
      port: 443
      allowedRoutes:
        namespaces:
          from: All
```
> NOTE: Here I specify that I can route to specific namespaces if I want. Since I control the whole cluster, I'll specify that I can route to all namespaces, but if this were a shared cluster you can specify that this can only work with specific namespaces.
{: .prompt-info }

### HTTPRoute

And finally, this is the actual "ingress" replacement, using the Gateway that I defined in the Traefik namespace, I can define how the gateway will behave when hitting the application proxy:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-route
  namespace: my-namespace
spec:
  parentRefs:
    - name: traefik-gateway
      namespace: traefik
  hostnames:
    - example.agrohacksstuff.io
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /
      backendRefs:
        - name: my-service  # The name of the service to connect to
          port: 3000        # the port of the service
```

## Conclusion

If I come across any more that I use a lot, I'll add them here. I was thinking a kustomization.yaml file, but that might get its own article. Happy kubing!