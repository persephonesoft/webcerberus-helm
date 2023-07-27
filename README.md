<!--- app-name: WebCerberus application -->

## Ready Helm Chart with Containers from Docker Hub

This Helm Chart has been configured to pull the Container Images from the Docker Hub Public Repository.

A set of Webcerberus versions available for deploying on Kubernetes is:
 - 8.1.8518 (the latest version)
 - 7.5.8405

## Prerequisites

- Kubernetes 1.24+
- Helm 3.2.0+
- PV provisioner support in the underlying infrastructure
- ReadWriteMany volumes for deployment scaling
- MariaDB database
- Licence for WebCerberus application in a file 'A:\Path\To_your\webcerberus.lic'
- Credentials for access to the private Docker.io repository provided as the Kubernetes secret. See [Pull an Image from a Private Registry](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/#create-a-pod-that-uses-your-secret)
- (Optional) TLS Certificate for Ingress service

Before running the Helm release installation two secrets must be created in the Kubernetes namespace where you are planning to deploy the Webcerberus application:

 1. Create the Kubernetes namespace `psnspace`:
 ```console
kubectl create namespace psnspace --dry-run=client -o yaml | kubectl apply -f -
```

 2. Create a secret `webcerberus-license` containing WebCerberus licensing information:
 ```console
kubectl create secret generic webcerberus-license --from-file A:\Path\To_your\webcerberus.lic --namespace psnspace --dry-run=client -o yaml | kubectl apply -f -
```

 3. Create a secret `webcerberus-docker-registry-creds` containing ImagePullSecret for the Wencerberus images pulling:
 ```console
kubectl create secret docker-registry webcerberus-docker-registry-creds --docker-server=https://index.docker.io/v1/ --docker-username=persephonesoft --docker-password=<put_your_password_here> --docker-email=mkravchuk@persephonesoft.com -n psnspace --dry-run=client -o yaml | kubectl apply -f -
```

 4. Prepare a connection string for access to the MariaDB in format: `db_user/db_user-secret@psnmaria.db.host:3306/persephone-db`.

 The connection string can be passed via the `--set ` option:
 ````console
 helm install ... --set env.ENVPSN_MariaDB_ConnectionString=<connection-string>
 ````
 or by reference on the Kubernetes secret name. 
 
 ***Create a secret `webcerberus-mariadb-connection-string` containing the connection string in a key `connection-string` using the following simple YAML file:
 ```console
apiVersion: v1
kind: Secret
metadata:
  name: webcerberus-mariadb-connection-string
type: Opaque
stringData:
    connection-string: "db_user/db_user-secret@psnmaria.db.host:3306/persephone-db"
~
````
    ***Notification: Any secret name can be used but the key name must be `connection-string`.

Then deploy the above secret file as follows:
````console
kubectl apply -f maria-db-ysecret.yaml --namespace psnspace
````

Point out the secret's name in the Helm parameter `.Value.env_from_secret.ENVPSN_MariaDB_ConnectionString`. If the secrte name is empty (is not provided), the `.Value.env.ENVPSN_MariaDB_ConnectionString` will be used.

5. (Optional) Cerate the Kubernetes secret containing the Ingress TLS certificate from .pfx-file:
 ```console
openssl pkcs12 -in pfx-filename.pfx -nocerts -out key-filename.key
openssl rsa -in key-filename.key -out key-filename-decrypted.key
openssl pkcs12 -in pfx-filename.pfx -clcerts -nokeys -out crt-filename.crt  ##remove clcerts to get the full chain in your cert
kubectl create secret tls your-tls-secret-name --cert crt-filename.crt --key key-filename-decrypted.key
```
The secret name `your-tls-secret-name` is used in the `ingresses.webcernerus.tls` section of the Helm value file. By default, the section is commented and the ingress service for Webcerberus will be created in HTTTP mode only.

## Installing the Chart

 To install the chart with the release name `my-release` in te Kubernetes namespace `psnspace`, run next commands:

```console
helm repo add persephone-helm https://persephonesoft.github.io/webcerberus-helm/
helm repo update
helm install my-release persephone-helm/webcerberus --set imagePullSecrets[0].name=webcerberus-docker-registry-creds --namespace psnspace
```
if the MariaDB connection string is in Kubernetes secret and secret's name is in `.Value.env_from_secret.ENVPSN_MariaDB_ConnectionString`, or:
```console
helm repo add persephone-helm https://persephonesoft.github.io/webcerberus-helm/
helm repo update
helm install my-release persephone-helm/webcerberus --set imagePullSecrets[0].name=webcerberus-docker-registry-creds,env.ENVPSN_MariaDB_ConnectionString="root/MySecret@psnmaria.db:3306/persephone" --namespace psnspace
```
if the MariaDB connection string is provided as a string parameter.

These commands deploy the latest version of WebCerberus to the Kubernetes cluster in the default configuration. The [Parameters](#parameters) section lists the parameters that can be configured during installation.

For deploying the Webcerberus of a specific version provide the version string as the Helm install --version parameter. For example, to install the Webcerberus of version 8.1.8518 run the command:
```console
helm install my-release persephone-helm/webcerberus --version 8.1.8518 --set imagePullSecrets[0].name=webcerberus-docker-registry-creds --namespace psnspace
```

## Mounting the GPFS volume for BLAST operation

Here's an example of using `volumeClaimTemplates` for a GPFS (General Parallel File System) volume in a StatefulSet:

Assuming you have already set up the GPFS storage and created a GPFS-specific storage class (e.g., `gpfs-storage-class`), it can be used in the following configuration:

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: my-gpfs-statefulset
spec:
  serviceName: my-service
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: my-container
          image: my-image:latest
          ports:
            - containerPort: 80
          volumeMounts:
            - name: data
              mountPath: /data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: gpfs-pvc
  volumeClaimTemplates:
    - metadata:
        name: gpfs-pvc
      spec:
        storageClassName: gpfs-storage-class  # GPFS-specific storage class
        accessModes:
          - ReadWriteMany  # GPFS supports ReadWriteMany for shared access
        resources:
          requests:
            storage: 10Gi  # Requested size for each PVC
        volumeMode: Filesystem
        # Add any additional GPFS-specific mount options as needed, like vers=4.1
```

Explanation:
1. The StatefulSet creates three replicas of the pod, each with its own PVC.
2. The `volumeClaimTemplates` section defines a template for creating the PVCs. In this example, we named it `gpfs-pvc`.
3. The `gpfs-pvc` PVC will be created based on the GPFS-specific storage class (`gpfs-storage-class`) defined in the `storageClassName` field.
4. The `accessModes` is set to `ReadWriteMany` to allow shared access to the GPFS volume.
5. `resources.requests.storage` specifies the requested storage size for each PVC (e.g., 10Gi).
6. The `volumeMode` is set to `Filesystem` to indicate a file system type volume.


The GPFS volume parameters can be configured via the `persistence.blast.gpfs` section of the Helm Value file. To make the Webcerberus deployment to use GPFS volume set `persistence.blast.gpfs.useGpfs: true`. Please make sure to adjust the `storageClassName`, `resources.requests.storage`, and any other mount options according to your GPFS setup and requirements.


## Uninstalling the Chart

To uninstall/delete the `my-release` statefulset:

```console
helm uninstall my-release -n psnspace
```

The command removes all the Kubernetes components associated with the chart and deletes the release. Use the option `--purge` to delete all history too. Remove manually persistent volumes created by the release and the secrets created on steps 2 and 3 of the installation guide.

## Parameters

See the explanation of the parameters in the file `webcerberus-helm\charts\webcerberus\values.yaml`
