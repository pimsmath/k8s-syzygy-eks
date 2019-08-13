I've added a policy in IAM called syzygy-k8s-terraform, a snapshot (possibly out
of date) of the config is available in
[./docs/syzygy-k8s-terraform.json](./docs/syzygy-k8s-terraform.json). Assuming
you have a user called `iana` with that policy attached, the files in the
terraform directory should apply to create a new cluster.

```bash
$ terraform init
$ terraform apply
```

If the cluster deploys OK, add the config to your `~/.kube/config`
```bash
$ aws --profile=iana eks list-clusters
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
```
$ kubectl version
Client Version: version.Info{Major:"1", Minor:"14", GitVersion:"v1.14.3", GitCommit:"5e53fd6bc17c0dec8434817e69b04a25d8ae0ff0", GitTreeState:"clean", BuildDate:"2019-06-06T01:44:30Z", GoVersion:"go1.12.5", Compiler:"gc", Platform:"darwin/amd64"}
Server Version: version.Info{Major:"1", Minor:"13+", GitVersion:"v1.13.8-eks-a977ba", GitCommit:"a977bab148535ec195f12edc8720913c7b943f9c", GitTreeState:"clean", BuildDate:"2019-07-29T20:47:04Z", GoVersion:"go1.11.5", Compiler:"gc", Platform:"linux/amd64"}

$ k get nodes
NAME                                       STATUS   ROLES    AGE     VERSION
ip-10-1-1-224.us-west-2.compute.internal   Ready    <none>   8m29s   v1.13.7-eks-c57ff8
ip-10-1-2-85.us-west-2.compute.internal    Ready    <none>   8m48s   v1.13.7-eks-c57ff8
ip-10-1-3-122.us-west-2.compute.internal   Ready    <none>   8m30s   v1.13.7-eks-c57ff8
```

If you don't see any worker nodes, check the aws iam role configuration.
