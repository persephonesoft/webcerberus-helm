<!--- app-name: WebCerberus application -->

## Ready Helm Chart with Containers from Docker Hub

This Helm Chart has been configured to pull the Container Images from the Docker Hub Public Repository.
The following command allows you to download and install all the charts from this repository.

```console
$ helm repo add my-repo https://ykjumper.github.io/webcerberus-helm/
$ helm install my-release persephone-helm/webcerberus
```

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- PV provisioner support in the underlying infrastructure
- ReadWriteMany volumes for deployment scaling
- MariaDB database
- Licence for WebCerberus application as Kubernetes configMap 'webcerberus-license'
- (Optional) TLS Certificate for Ingress service

## Installing the Chart

 To install the chart with the release name `my-release`:

```console
$ helm repo add my-repo https://ykjumper.github.io/webcerberus-helm/
$ helm repo update
$ helm install my-release persephone-helm/webcerberus
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