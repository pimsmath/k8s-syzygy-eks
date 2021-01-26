I've added a policy in IAM called syzygy-k8s-terraform, a snapshot (possibly out
of date) of the config is available in
[./docs/syzygy-k8s-terraform.json](./docs/syzygy-k8s-terraform.json). Assign
that policy to the IAM object you will be creating the cluster as. I used an IAM
user called iana. The files in the terraform directory should apply to create a
new cluster.

```bash
$ terraform init
$ terraform apply
```

If the cluster deploys OK, add the config to your `~/.kube/config`

```bash
$ aws --profile=iana --region=us-west-2 eks list-clusters
...
{
    "clusters": [
        "syzygy-eks-tJSxgQlx"
    ]
}

$ aws --profile=iana --region=us-west-2 eks update-kubeconfig \
  --name=syzygy-eks-tJSxgQlx
```

And check that you can interact with the cluster
```bash
$ kubectl version
Client Version: version.Info{Major:"1", Minor:"14", GitVersion:"v1.14.3", GitCommit:"5e53fd6bc17c0dec8434817e69b04a25d8ae0ff0", GitTreeState:"clean", BuildDate:"2019-06-06T01:44:30Z", GoVersion:"go1.12.5", Compiler:"gc", Platform:"darwin/amd64"}
Server Version: version.Info{Major:"1", Minor:"13+", GitVersion:"v1.13.8-eks-a977ba", GitCommit:"a977bab148535ec195f12edc8720913c7b943f9c", GitTreeState:"clean", BuildDate:"2019-07-29T20:47:04Z", GoVersion:"go1.11.5", Compiler:"gc", Platform:"linux/amd64"}

$ kubectl get nodes
NAME                                       STATUS   ROLES    AGE     VERSION
ip-10-1-1-224.us-west-2.compute.internal   Ready    <none>   8m29s   v1.13.7-eks-c57ff8
ip-10-1-2-85.us-west-2.compute.internal    Ready    <none>   8m48s   v1.13.7-eks-c57ff8
ip-10-1-3-122.us-west-2.compute.internal   Ready    <none>   8m30s   v1.13.7-eks-c57ff8
```

If you don't see any worker nodes, check the AWS IAM role configuration.

## Helm
We will be using RBAC (see the [helm RBAC
documentation](https://helm.sh/docs/using_helm/#role-based-access-control), so
we need to configure a role for tiller and initialize tiller.
```
$ kubectl create -f docs/rbac-config.yaml
$ helm init --service-account tiller --history-max 200
```

Pick a domain name where the service will run. For this example, we will be
using [k8s.syzygy.ca]. The service must be run over TLS/SSL so we need to
arrange for certificates and keys. For the example we will use ACM ([Amazon
Certificate Manager](https://aws.amazon.com/certificate-manager/), but
[letsencrypt via
cert-manager](https://docs.bitnami.com/kubernetes/how-to/secure-kubernetes-services-with-ingress-tls-letsencrypt/)
also works (at the expense of installing an extra chart). In ACM create a new
certificate and populate the DNS validation CNAME as requested. Once the
certificate is issued, add the arn to `shib.acm.arn` in the `one-two-jupyterhub`
config.yaml.


Install a release of one-two-syzygy, e.g.
```bash
$ helm upgrade --wait --install --namespace=syzygy syzygy one-two-syzygy \
  --values=one-two-syzygy/values.yaml -f config.yaml \
  --set-file "shib.shibboleth2xml=./files/shibboleth2.xml" \
  --set-file "shib.idpmetadataxml=./files/idp-metadata.xml" \
  --set-file "shib.attributemapxml=./files/attribute-map.xml"
```

Grab the DNS name of the LoadBalancer for the shib service and populate your DNS
with it.
```
$ kubectl -n syzygy get svc/sp
NAME   TYPE           CLUSTER-IP      EXTERNAL-IP                                                              PORT(S)                      AGE
sp     LoadBalancer   172.20.28.153   a0d9590f3be0111e983c802cecd4bb8d-668104507.us-west-2.elb.amazonaws.com   80:30656/TCP,443:30792/TCP   5m30s
```


# Suggested values: advanced users of Kubernetes and Helm should feel
# free to use different values.
RELEASE=jhub
NAMESPACE=jhub

helm upgrade --cleanup-on-fail \
  --install $RELEASE jupyterhub/jupyterhub \
  --namespace $NAMESPACE \
  --create-namespace \
  --version=0.10.6 \
  --values config.yaml