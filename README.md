# Syzygy EKS Resources

The terraform file in this repo define an autoscaling cluster suitable for use
with zero to jupyterhub. They define an EKS cluster with self-managed nodes
along with the relevant policies and roles for isotoma/autoscaler to work
properly. Things are typically deployed with terragrunt, but you can also use
terraform directly if you wish. I think things should work for terraform 1.2+.

```bash
$ terraform init
$ terraform apply
```

If the cluster deploys OK, add the config to your `~/.kube/config`

```bash
$ aws eks list-clusters
...
{
    "clusters": [
        "syzygy-eks-tJSxgQlx"
    ]
}

$ aws eks update-kubeconfig --name=syzygy-eks-tJSxgQlx
```

And check that you can interact with the cluster
```bash
$ kubectl version
Client Version: version.Info{Major:"1", Minor:"22", GitVersion:"v1.22.4", GitCommit:"b695d79d4f967c403a96986f1750a35eb75e75f1", GitTreeState:"clean", BuildDate:"2021-11-17T15:48:33Z", GoVersion:"go1.16.10", Compiler:"gc", Platform:"darwin/amd64"}
Server Version: version.Info{Major:"1", Minor:"22+", GitVersion:"v1.22.12-eks-6d3986b", GitCommit:"dade57bbf0e318a6492808cf6e276ea3956aecbf", GitTreeState:"clean", BuildDate:"2022-07-20T22:06:30Z", GoVersion:"go1.16.15", Compiler:"gc", Platform:"linux/amd64"}

$ kubectl get nodes
NAME                                          STATUS   ROLES    AGE   VERSION
ip-10-0-2-215.ca-central-1.compute.internal   Ready    <none>   38m   v1.22.12-eks-ba74326
ip-10-0-3-235.ca-central-1.compute.internal   Ready    <none>   38m   v1.22.12-eks-ba74326
```

### Autoscaler

On completion, terraform/terragrunt should report some output including

  * The cluster name (e.g. syzygy-eks-tJSxgQlx)
  * The autoscaler role arn (e.g. eks.amazonaws.com/role-arn:
    "arn:aws:iam::830114512327:role/syzygy-eks-miYWfO20-cluster_autoscaler-role")

Add these to a yaml file, e.g.
```bash
$ vi autoscaler.yaml
awsRegion: ca-central-1

cloudConfigPath: ''

rbac:
  create: true
  serviceAccount:
    # This value should match local.k8s_service_account_name in locals.tf
    name: cluster-autoscaler
    annotations:
      # This value should match the ARN of the role created by module.iam_assumable_role_admin in irsa.tf
      eks.amazonaws.com/role-arn: "arn:aws:iam::830114512327:role/syzygy-eks-miYWfO20-cluster_autoscaler-role"

autoDiscovery:
  clusterName: "syzygy-eks-miYWfO20"
  enabled: true
```
Then deploy the chart with these values.
```bash
$ helm repo add https://isotoma.github.io/charts
$ helm update
$ helm install cluster-autoscaler \
  --namespace kube-system autoscaler/cluster-autoscaler \
  --values=autoscaler.yaml
```

The autoscaler should show up in the kube-system namespace. Take a look at the
pod logs to check that things are working OK.

#### Gotchas

Some things to look for in the logs...

  1. Make sure your nodes have the right labels and annotations.
  1. If you see an error about `/etc/gce.conf`, this is a recent bug in the
     autoscaler chart, see
     [autoscaler/issues/5143](https://github.com/kubernetes/autoscaler/issues/5143) for more details, but for a quick workaround, just make sure the autoscaler.yaml has `cloudConfigPath: ''` at the top level.
  1. If you see errors from about not having permission to read
     `autoscaling:DescribeTags` there is probably a mistake in the role
     configuration. We are using IRSA to do this and it is a bit complicated,
     but the general idea is a k8s service account will need to correspond to
     some IAM role with the right set of permissions to do the autoscaling. The
     most common problems are role name mismatches.
     ```bash
     $ kubectl -n kube-system get sa | grep autoscaler
     cluster-autoscaler
     $ kubectl -n kube-system describe sa/cluster-autoscaler
     Name:                cluster-autoscaler
     Namespace:           kube-system
     Labels:              app.kubernetes.io/instance=cluster-autoscaler
                          app.kubernetes.io/managed-by=Helm
                          app.kubernetes.io/name=aws-cluster-autoscaler
                          helm.sh/chart=cluster-autoscaler-9.20.1
     Annotations:         eks.amazonaws.com/role-arn: arn:aws:iam::830114512327:role/syzygy-eks-J8kLcrxj-cluster_autoscaler-role
                          meta.helm.sh/release-name: cluster-autoscaler
                          meta.helm.sh/release-namespace: kube-system
     Image pull secrets:  <none>
     Mountable secrets:   cluster-autoscaler-token-s69wn
     Tokens:              cluster-autoscaler-token-s69wn
     Events:              <none>
     ```
     In this case, check in IAM for the autoscaler role listed in the
     Annotations. Make sure that role has the right permissions (listed in
     irsa.tf). It is also possible for things to go wrong in the conditions for
     the `cluster_autoscaler_sts` iam policy document condition checks. This
     checks and OIDC provider value against a string with the format
     "system:serviceaccount:kube-system:cluster-autoscaler" where the last
     component is the name from above. It's _very_ easy to make mistakes here
     and the autoscaler isn't easy to debug so be careful.
  1. Check the syntax in `autoscaler.yaml`. At some point
     `serviceAccountAnnotations` was replaced with `serviceAccount` and
     `annotations` as a key. I've missed this change *twice* now and the
     autoscaler just happily deploys but falls over trying to check
     `annotations:DescribeTags`.

