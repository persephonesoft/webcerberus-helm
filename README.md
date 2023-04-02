<!--- app-name: WebCerberus application -->

## Ready Helm Chart with Containers from Docker Hub

This Helm Chart has been configured to pull the Container Images from the Docker Hub Public Repository.
The following command allows you to download and install all the charts from this repository.

```console
$ helm repo add my-repo https://persephonesoft.github.io/webcerberus-helm/
$ helm install my-release persephone-helm/webcerberus
```

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- PV provisioner support in the underlying infrastructure
- ReadWriteMany volumes for deployment scaling
- MariaDB database
- Licence for WebCerberus application as Kubernetes configMap 'webcerberus-license'
- Credentials for access to the private Docker.io repository provided as the Kubernetes secret. See [Pull an Image from a Private Registry](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/#create-a-pod-that-uses-your-secret)
- (Optional) TLS Certificate for Ingress service

## Installing the Chart

 To install the chart with the release name `my-release`:

```console
$ helm repo add my-repo https://persephonesoft.github.io/webcerberus-helm/
$ helm repo update
$ helm install my-release persephone-helm/webcerberus --set imagePullSecrets[0].name="image-pull-secret-name"
```

These commands deploy WebCerberus the Kubernetes cluster in the default configuration. The [Parameters](#parameters) section lists the parameters that can be configured during installation.

> **Tip**: List all releases using `helm list`

## Uninstalling the Chart

To uninstall/delete the `my-release` statefulset:

```console
$ helm delete my-release
```

The command removes all the Kubernetes components associated with the chart and deletes the release. Use the option `--purge` to delete all history too. Remove manually persistent volumes created by the release.

## Parameters

See parameters explanation in file webcerberus-helm\charts\webcerberus\values.yaml

## How to create ImagePullSecret

As an option the secret can be created from the CLI using parameters provided by the Persephonesoft
```console
kubectl create secret docker-registry [secret-name] --docker-server=[your-registry-server] --docker-username=[your-name] --docker-password=[your-pword] --docker-email=[your-email] --namespace=[you-namespace]
```
where:
 - [secret-name] is the secret name.
 - [your-registry-server] is your Private Docker Registry FQDN. Use https://index.docker.io/v1/ for DockerHub.
 - [your-name] is your Docker username.
 - [your-pword] is your Docker password.
 - [your-email] is your Docker email.
 - [you-namespace] is Kubernetes namespace where you are running the application

Example:
```console
kubectl create secret docker-registry image-pull-secret-name \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=persephonesoft \
  --docker-password=<dockrHubUserPassword> \
  --docker-email=mkravchuk@persephonesoft.com \
  --namespace=persephone
```
