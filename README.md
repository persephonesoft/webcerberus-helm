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
- Licence for WebCerberus application in a file 'A:\Path\To_your\webcerberus.lic'
- Credentials for access to the private Docker.io repository provided as the Kubernetes secret. See [Pull an Image from a Private Registry](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/#create-a-pod-that-uses-your-secret)
- (Optional) TLS Certificate for Ingress service

Before run the Helm release installation two secrets must be created the Kubernetes namespace where you are planning deploy Webcerberus application:

 1. Create the Kubernetes namespace `psnspace`:
 ```console
$ kubectl create namespace psnspace --dry-run=client -o yaml | kubectl apply -f -
```

 2. Create a secret `webcerberus-license` containing WebCerberus licensing information:
 ```console
$ kubectl create secret generic webcerberus-license --from-file A:\Path\To_your\webcerberus.lic --namespace psnspace --dry-run=client -o yaml | kubectl apply -f -
```

 3. Create a secret <webcerberus-docker-registry-creds> containing ImagePullSecret for the Wencerberus images pulling:
 ```console
$ kubectl create secret docker-registry <webcerberus-docker-registry-creds> --docker-server=https://index.docker.io/v1/ --docker-username=persephonesoft --docker-password=*** --docker-email=mkravchuk@persephonesoft.com -n psnspace --dry-run=client -o yaml | kubectl apply -f -
```

## Installing the Chart

 To install the chart with the release name `my-release` in te Kubernetes namespace `psnspace`:

```console
$ helm repo add persephone-helm https://persephonesoft.github.io/webcerberus-helm/
$ helm repo update
$ helm install my-release persephone-helm/webcerberus --set imagePullSecrets[0].name="<webcerberus-docker-registry-creds>",env.ENVPSN_MariaDB_ConnectionString="root/MySecret@psnmaria.db:3306/persephone" --namespace psnspace --dry-run=client -o yaml | kubectl apply -f -
```

These commands deploy WebCerberus the Kubernetes cluster in the default configuration. The [Parameters](#parameters) section lists the parameters that can be configured during installation.

> **Tip**: List all releases using `helm list`

## Uninstalling the Chart

To uninstall/delete the `my-release` statefulset:

```console
$ helm uninstall my-release -n psnspace
```

The command removes all the Kubernetes components associated with the chart and deletes the release. Use the option `--purge` to delete all history too. Remove manually persistent volumes created by the release.

## Parameters

See parameters explanation in file webcerberus-helm\charts\webcerberus\values.yaml

