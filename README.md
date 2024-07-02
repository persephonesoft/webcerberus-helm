<!--- app-name: WebCerberus application -->

## Ready Helm Chart with Containers from Docker Hub

This Helm Chart has been configured to pull the Container Images from the Docker Hub Public Repository.

A set of Webcerberus versions available for deploying on Kubernetes is:
 - 9.1.8921 (the latest version)
	- Remove "email" login provider
 - 9.1.8915 
	- New Feature: Variant distances for region
	- Redesign: Export sequences 
	- Core changes: Change track settings in storage
	- New Feature: Allow change Bedgraph track view for the whole mapset
	- PSH: Fixed deleting VCF data
 - 8.6.8825
 - 8.3.8648-0
     Fixed permission issue with changing user id in the pod security context.
 - 8.1.8518-2
 - 8.1.8518-1
 - 8.1.8518
 - 7.5.8405

## Prerequisites

- Kubernetes 1.24+ (or latest Minikube, Docker Desktop tools)
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

 3. Create a secret `webcerberus-docker-registry-creds` containing ImagePullSecret for the Webcerberus images pulling:
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

 5. (Optional) If you a planing to use the application custom-config from a secret please create secret `persephone-custom-config`:
 ```console
kubectl create secret generic persephone-custom-config --from-file C:\YourPath\to\custom.config  --namespace psnspace --dry-run=client -o yaml | kubectl apply -f -
```

 6. (Optional) Cerate the Kubernetes secret containing the Ingress TLS certificate from .pfx-file:
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

## Mounting an existing GPFS Persistent Volume for BLAST operation

NOTICE: The volume type can not be changed after the chart installation.

NOTICE: If the podSecurityContext has been changed to comply with file system permissions on the existing GPFS volume the migration procedure should be performed to preserve persistent volumes. See the section below for details.

Here is an example of using an existing GPFS (General Parallel File System) Persistent Volumes in a StatefulSet. Assuming the GPFS Persistent Volumes `blast-data-pv-claim-name` and `blast-script-pv-claim-name` are already created , they are used in the following configuration:

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: my-release-webcerberus
  namespace: "psnspace"
  labels:
    app: webcerberus
    chart: webcerberus-8.1.8518-2
    release: my-release
    app.kubernetes.io/component: webcerberus
spec:
  replicas: 1
  serviceName: my-release-webcerberus
  selector:
    matchLabels:
      app.kubernetes.io/component: webcerberus
  template:
    metadata:
      labels:
        app: webcerberus
        release: my-release
        app.kubernetes.io/component: webcerberus
    spec:
      volumes:
        ## ...
        - name: blast-data
          persistentVolumeClaim:
            claimName: blast-data-pv-claim-name
            readOnly: false
        - name: blast-script
          persistentVolumeClaim:
            claimName: blast-script-pv-claim-name
            readOnly: false
      ## ...
      containers:
        - name: webcerberus
          ## ...
          env:
            ## ...
            - name: ENVPSN_Blast_ProgramDirectory
              value: /opt/blastscript/mount/point
            - name: ENVPSN_File_Storage_Path
              value: /opt/blastdata/mount/point
            ## ...
          volumeMounts:
            # ...
            - name: blast-data
              mountPath: /opt/blastdata/mount/point
            - name: blast-script
              mountPath: /opt/blastscript/mount/point
```

Explanation:
1. The StatefulSet creates a replica of the pod.
2. In the `volumes` section two volumes are defined by referring to their `persistentVolumeClaim`s: `blast-data` and `blast-script`.
3. In the `containers` section the volumes are mounted at the specific mount points and environment variables are defined with corresponding paths.


The GPFS volume parameters can be configured via the `persistence.blast.gpfs` section of the Helm Value file. To make the Webcerberus deployment to use GPFS volume set `persistence.blast.gpfs.useGpfs: true`. Please make sure to adjust the `persistence.blast.gpfs.gpfsVolumes`, `persistence.blast.gpfs.gpfsVolumesMounts`, and any other mount options according to your GPFS setup and requirements. Don't forget to change the `podSecutiryContext` section parameters according to granted permissions on the GPFS volume file system.
```yaml
## ...
podSecurityContext:
  enabled: true
  runAsUser: 32001  ## Change to user ID of the User having appropriate permissions on the GPFS volume
  runAsGroup: 32001 ## Change to user ID of the Group having appropriate permissions on the GPFS volume
  fsGroup: 32001    ## Change to group ID of the Group having appropriate permissions on the GPFS volume
  fsGroupChangePolicy: "Always"
## ...
persistence:
    ##...
  blast:
    ## @param persistence.blast.gpfs.useGpfsPvs defines if the existing Persistent Volumes should be used.
    ##
    ## @param persistence.blast.gpfs.gpfsVolumes provides the PV list.
    ##
    ## @param persistence.blast.gpfs.gpfsVolumesMounts is pointing out the volumes mounts.
    ## the 'env:' section below should be updated according to selected mount points.
    gpfs:
      useGpfsPvs: true
      gpfsVolumes:
      - name: blast-data
        persistentVolumeClaim:
          claimName: blast-data-pv-claim-name
          readOnly: false
      - name: blast-script
        persistentVolumeClaim:
          claimName: blast-script-pv-claim-name
          readOnly: false
      gpfsVolumesMounts:
      - name: blast-data
        mountPath: /opt/blastdata/mount/point
      - name: blast-script
        mountPath: /opt/blastscript/mount/point
    ## ...
env:
  ## ...
  ENVPSN_Blast_ProgramDirectory: '/opt/blastscript/mount/point'
  ENVPSN_File_Storage_Path: '/opt/blastdata/mount/point'
  ## ...
```

## Procedure of the migration to other pod security context

In case of changing the statefullSet security context, to preserve persistent volumes the file system permission should be updated. To change permission on the existing (already created during the application installation) persistent volume the initialization container should be running once under the root user. This possibility is provided by switching on the containerSecurityContext:
```yaml
## ...
  ## Init container' Security Context
  ## Note: the chown of the data folder is done to containerSecurityContext.runAsUser
  ## and not the below volumePermissions.containerSecurityContext.runAsUser
  ## @param volumePermissions.containerSecurityContext.runAsUser User ID for the init container
  ##
  containerSecurityContext:
    enabled: true ## This is switching on the initContainer containerSecurityContext
    runAsUser: 0
    privileged: true
    allowPrivilegeEscalation: true
  ## ...
```
By default the `containerSecurityContext` is disabled: `volumePermissions.containerSecurityContext.enabled=false`

If the Kubernetes PodSecurityPolicy/PodSecurity Admission denies running containers under the root user the application's persistent volumes should be recreated.

## Uninstalling the Chart

To uninstall/delete the `my-release` statefulset:

```console
helm uninstall my-release -n psnspace
```

The command removes all the Kubernetes components associated with the chart and deletes the release. Use the option `--purge` to delete all history too. Remove manually persistent volumes created by the release and the secrets created on steps 2 and 3 of the installation guide.

## Parameters

See the explanation of the parameters in the file `webcerberus-helm\charts\webcerberus\values.yaml`

## Installing Webcerberus in local environment

For development, testing or experimental purposes, Webcerberus application can be installed locally. As a local environment can be used the [Minikube](https://kubernetes.io/docs/home/) or [Docker Desktop](https://www.docker.com/products/docker-desktop/) (for Windows or MacOS only) tools that facilitate running a single-node Kubernetes cluster on a local machine.

The local Webcerberus installation requires the same prerequisites, as it is described in the "Prerequisites" section.
Before running the Helm release installation two secrets must be created in the Kubernetes namespace where you are planning to deploy the Webcerberus application:

 1. Create the Kubernetes namespace `psnspace`:
 ```console
kubectl create namespace psnspace --dry-run=client -o yaml | kubectl apply -f -
```

 2. Create a secret `webcerberus-license` containing WebCerberus licensing information:
 ```console
kubectl create secret generic webcerberus-license --from-file A:\Path\To_your\webcerberus.lic --namespace psnspace --dry-run=client -o yaml | kubectl apply -f -
```

 3. Create a secret `webcerberus-docker-registry-creds` containing ImagePullSecret for the Webcerberus images pulling:
 ```console
kubectl create secret docker-registry webcerberus-docker-registry-creds --docker-server=https://index.docker.io/v1/ --docker-username=persephonesoft --docker-password=<put_your_password_here> --docker-email=mkravchuk@persephonesoft.com -n psnspace --dry-run=client -o yaml | kubectl apply -f -
```

 4. The  MariaDB database can be installed in the same namespace from any public repo.As an example, the MariaDB 

```console
helm repo add azure-marketplace https://marketplace.azurecr.io/helm/v1/repo
helm repo update
helm install mariadb azure-marketplace/mariadb --namespace psnspace --set architecture=standalone,auth.rootPassword="MySecret1",auth.database=persephone,primary.persistence.enabled=true -f 'A:\Path\To\\mariadb-helm-values.yaml'
```
where release name is `mariadb`, `mariadb-helm-values.yaml` contains custom configuration required by Webcerberus:

```yaml
## @param nameOverride String to partially override mariadb.fullname
##
nameOverride: "psnmariadb"

## @param architecture MariaDB architecture (`standalone` or `replication`)
##
architecture: standalone

## Mariadb Primary parameters
##
primary:
  ## @param primary.configuration [string] MariaDB Primary configuration to be injected as ConfigMap
  ## ref: https://mysql.com/kb/en/mysql/configuring-mysql-with-mycnf/#example-of-configuration-file
  ##
  configuration: |-
    [mysqld]
    skip-name-resolve
    explicit_defaults_for_timestamp
    basedir=/opt/bitnami/mariadb
    plugin_dir=/opt/bitnami/mariadb/plugin
    port=3306
    socket=/opt/bitnami/mariadb/tmp/mysql.sock
    tmpdir=/opt/bitnami/mariadb/tmp
    max_allowed_packet=16M
    bind-address=*
    pid-file=/opt/bitnami/mariadb/tmp/mysqld.pid
    log-error=/opt/bitnami/mariadb/logs/mysqld.log
    character-set-server=UTF8
    collation-server=utf8_general_ci
    slow_query_log=0
    slow_query_log_file=/opt/bitnami/mariadb/logs/mysqld.log
    long_query_time=10.0
    lower_case_table_names=1 
    log_bin_trust_function_creators=ON
    character_set_server=utf8
    innodb_buffer_pool_size=4294967296
    key_buffer_size=33554432
    innodb_log_file_size=536870912
    tmp_table_size=33554432
    max_heap_table_size=33554432
    join_buffer_size=2097152
    query_cache_size=0
    max_allowed_packet=67108864
    max_connections=500
    innodb_log_buffer_size=16777216
    sort_buffer_size=2097152
    table_open_cache=2000
    open_files_limit=16384
    net_write_timeout=3600
    net_read_timeout=3600
    [client]
    port=3306
    socket=/opt/bitnami/mariadb/tmp/mysql.sock
    default-character-set=UTF8
    plugin_dir=/opt/bitnami/mariadb/plugin
    [manager]
    port=3306
    socket=/opt/bitnami/mariadb/tmp/mysql.sock
    pid-file=/opt/bitnami/mariadb/tmp/mysqld.pid

```
 5. Prepare a connection string for access to the MariaDB in format: `db_user/db_user-secret@psnmaria.db.host:3306/persephone-db`.

 The connection string can be passed via the `--set ` option:
 ````console
 helm install ... --set env.ENVPSN_MariaDB_ConnectionString="root/MySecret1@mariadb-psnmariadb:3306/persephone"
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
    connection-string: "root/MySecret1@mariadb-psnmariadb:3306/persephone"
~
````
    ***Notification: Any secret name can be used but the key name must be `connection-string`.
    ***The MariaDB host name here 'mariadb-psnmariadb' compraises on two parts: <release name>-<Value.nameOverride>

Then deploy the above secret file as follows:
````console
kubectl apply -f maria-db-ysecret.yaml --namespace psnspace
````
where `maria-db-ysecret.yaml` contains the secret definition:
```yaml
apiVersion: v1
kind: Secret
metadata:
 name: webcerberus-mariadb-connection-string
type: Opaque
stringData:
   connection-string: "root/MySecret1@mariadb-psnmariadb:3306/persephone"
```
 6. To install the chart with the release name `my-release` in te Kubernetes namespace `psnspace`, run next commands:

```console
helm repo add persephone-helm https://persephonesoft.github.io/webcerberus-helm/
helm repo update
helm install my-release persephone-helm/webcerberus --set imagePullSecrets[0].name=webcerberus-docker-registry-creds --namespace psnspace
```
if the MariaDB connection string is in Kubernetes secret and secret's name is in `.Value.env_from_secret.ENVPSN_MariaDB_ConnectionString`, or:
```console
helm repo add persephone-helm https://persephonesoft.github.io/webcerberus-helm/
helm repo update
helm install my-release persephone-helm/webcerberus --set imagePullSecrets[0].name=webcerberus-docker-registry-creds,env.ENVPSN_MariaDB_ConnectionString="root/MySecret1@mariadb-psnmariadb:3306/persephone" --namespace psnspace
```
if the MariaDB connection string is provided as a string parameter.

These commands deploy the latest version of WebCerberus to the Kubernetes cluster in the default configuration. The [Parameters](#parameters) section lists the parameters that can be configured during installation.

For deploying the Webcerberus of a specific version provide the version string as the Helm install --version parameter. For example, to install the Webcerberus of version 8.1.8518 run the command:
```console
helm install my-release persephone-helm/webcerberus --version 8.1.8518 --set imagePullSecrets[0].name=webcerberus-docker-registry-creds --namespace psnspace
```

7. As an option, the Webcerberus Helm charct can be pulled out, unpackaged and installed by a path to the  unpackaged chart. It may be usefull for develepment or debugging purposes. The unpacked files can be modified and changes easily applied in local environment.

To download release packge run next command:

```console
helm repo add persephone-helm https://persephonesoft.github.io/webcerberus-helm/
helm repo update

helm pull persephone-helm/webcerberus --version 8.1.8518
```
the package of the specified version (or lates one, if no version is specified) will be downloaded to the current directory:

```console
PS C:\Download> ls

    Directory: C:\Download


Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
-a----         7/31/2023   3:26 PM          91393 webcerberus-8.1.8518.tgz

```
Unpack `webcerberus-8.1.8518.tgz` with any unpacker to your local drive.

```console
tar -xvzf ./webcerberus-8.1.8518.tgz
```

Now, the Webcerberus Helm chart is located in folder `./webcerberus` and you can modify any files you need.


```console
helm install lc-release C:\Downloads\webcerberus\charts\webcerberus --set imagePullSecrets[0].name=webcerberus-docker-registry-creds --namespace psnspace
```
or

```console
helm install lc-release C:\Downloads\webcerberus\charts\webcerberus --set imagePullSecrets[0].name=webcerberus-docker-registry-creds,env.ENVPSN_MariaDB_ConnectionString="root/MySecret1@mariadb-psnmariadb:3306/persephone" --namespace psnspace
```

if the MariaDB connection string is provided as a string parameter.



