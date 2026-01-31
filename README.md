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
Set .Values.custom_config.custom_config_from_secret=true in the Value file

 6. (Optional) Cerate the Kubernetes secret containing the Ingress TLS certificate from .pfx-file:
 ```console
openssl pkcs12 -in pfx-filename.pfx -nocerts -out key-filename.key
openssl rsa -in key-filename.key -out key-filename-decrypted.key
openssl pkcs12 -in pfx-filename.pfx -clcerts -nokeys -out crt-filename.crt  ##remove clcerts to get the full chain in your cert
kubectl create secret tls your-tls-secret-name --cert crt-filename.crt --key key-filename-decrypted.key -n psnspace
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


## Using a Custom CA Certificate for BLAST Operations

BLAST operations can be executed on external BLAST farms. To ensure secure communication, these remote calls use the **SSL protocol** with certificates issued by a private Certificate Authority (CA).

If the SSL certificate is signed by a private CA, you must install the corresponding custom CA certificate in the application containers to enable proper SSL validation.  

### How to Use a Custom CA Certificate

To configure the application to use a custom CA certificate:  

1. Enable the custom CA feature
   - Set the following parameter in your configuration:  
     ```yaml
     blast.custom-ca.useCustomCA: true
     ```

2. Provide the CA certificate as a Kubernetes Secret
   - The CA certificate must be stored in a Kubernetes Secret **before** deploying the application.  
   - Specify the Secret name in the configuration:  
     ```yaml
     blast.custom-ca.secretName: <your-secret-name>
     ```

The secret will be mounted in containers at the path `/etc/ssl/certs/blast-custom-ca.crt`. Additionally, the environment variable `SSL_CERT_FILE=/etc/ssl/certs/blast-custom-ca.crt` will be set.

### Creating the Kubernetes Secret

Before deploying, create a Kubernetes Secret that contains your CA certificate:  

```
sh
kubectl create secret generic <your-secret-name> --from-file=ca.crt=<path-to-your-ca-cert.crt> -n psnspace
```

This ensures the certificate is securely stored and available for the application.  

## Test SSL Connection Using the Custom CA
If your application uses tools like curl, wget, or openssl, test if they can trust the certificate.

Using openssl
Check if OpenSSL recognizes the CA:
````
sh
openssl s_client -connect <service-hostname>:443 -CAfile /etc/ssl/certs/blast-custom-ca.crt
````
If the certificate is trusted, you should see:
```
Verify return code: 0 (ok)
```
If there's an issue, you'll see a certificate verification failure.

Using curl
Try making a request:
```
sh
curl --cacert /etc/ssl/certs/blast-custom-ca.crt https://<service-url>
```
If the `SSL_CERT_FILE` environment variable is set, it is used as the `--cacert` value. If successful, the CA is available and trusted. If you get an SSL error, it may indicate that the CA certificate is missing or invalid.

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

## Migrating from Bitnami Solr to Standalone Solr Service

This chart has migrated from using the Bitnami Solr Helm chart to a standalone Solr service deployment. This section describes the changes and provides instructions for migrating existing data.

### Why the Change?

The primary motivation for this migration is **vendor-lock avoidance**. By switching from the Bitnami-packaged Solr to the official Apache Solr image, we gain:

- **No vendor dependency** - Using the official `library/solr` image from Docker Hub ensures long-term support and compatibility with upstream Solr releases
- **Standard directory layout** - The official Solr image uses the standard `/var/solr/data/` path, making it easier to follow official documentation and community resources
- **Simplified deployment** - No ZooKeeper dependency required for standalone mode
- **Direct control** - Full control over Solr configuration, schema, and configsets
- **Custom configset support** - WebCerberus-specific field types (`text_names`, `text_en`) with managed schema support

### Key Differences

| Aspect | Bitnami Solr | Standalone Solr (Official) |
|--------|--------------|----------------------------|
| Image | `bitnami/solr` | `library/solr` (official Apache) |
| Data Path | `/bitnami/solr/server/solr/` | `/var/solr/data/` |
| PVC Name | `data-<release>-solr-0` | `solr-data-<release>-solr-0` |
| Schema | Default managed schema | Custom schema with WebCerberus field types |
| User ID | 1001 | 8983 |
| Configsets | `/bitnami/solr/server/solr/configsets/` | `/var/solr/data/configsets/` |

### Data Migration Process

The chart includes a built-in migration feature that copies Solr index data, configurations, and configsets from an existing Bitnami Solr PVC to the new standalone Solr PVC.

#### What Gets Migrated

The migration init container handles:

1. **Configsets** - All configsets from `/bitnami-solr/server/solr/configsets/` (except `_default`)
2. **Main core** - The primary core (e.g., `persephone`) with its data and configuration
3. **User cores** - All user-specific cores matching the pattern `uXXXXXX` (e.g., `u014154`, `u002296`)
4. **Other named cores** - Any additional cores found in the Bitnami Solr home

#### Configuration Detection

For each core, the migration script reads the source `core.properties` file to determine the configuration mode:

- **ConfigSet reference** - If `configSet=<name>` is defined, the core references a shared configset
- **Embedded conf/ directory** - If the core has a `conf/` subdirectory, it's copied as a new configset
- **Flat config files** - If config files (`managed-schema`, `solrconfig.xml`) exist in the core root, they're copied directly
- **No local config** - Falls back to the main core's configset

### Migration Flag Files (`.migrated`)

The migration uses per-directory flag files to track what has been migrated. This provides granular control over the migration process.

#### How It Works

After successfully migrating each core or configset, a `.migrated` flag file is created in the target directory:

```
/var/solr/data/persephone/.migrated        # Main core
/var/solr/data/u014154/.migrated           # User core
/var/solr/data/u002296/.migrated           # User core
/var/solr/data/configsets/persephone/.migrated  # Configset
```

The flag file contains metadata about the migration:

```properties
migrated=true
source_core=persephone
migration_date=2026-01-31T10:30:00+00:00
```

#### Migration Behavior

- **Skip if flag exists** - If a `.migrated` file is found in the target directory, that core/configset is skipped
- **Migrate if no flag** - Only directories without the flag file are processed
- **No recursive flags** - Flags are only created at the top level of each migrated directory (not in subdirectories)

#### Re-Migrating Specific Directories

To re-migrate a specific core or configset, simply delete its `.migrated` flag file:

```console
# Exec into the running Solr pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash

# Remove the flag file for a specific core to allow re-migration
rm /var/solr/data/u014154/.migrated

# Or remove flag for a configset
rm /var/solr/data/configsets/persephone/.migrated
```

On the next pod restart (with migration enabled), the init container will re-migrate only the directories without flag files.

**Use cases for re-migration:**
- Corrupted data in a specific core
- Need to refresh configuration from Bitnami source
- Testing migration changes on a single core

#### Viewing Migration Status

To see which directories have been migrated:

```console
# List all migration flags
kubectl exec -it <pod-name> -n <namespace> -- find /var/solr/data -name ".migrated" -exec echo "=== {} ===" \; -exec cat {} \;

# Or just list the migrated directories
kubectl exec -it <pod-name> -n <namespace> -- find /var/solr/data -maxdepth 2 -name ".migrated" -exec dirname {} \;
```

### Prerequisites

- The existing Bitnami Solr PVC must be in the same namespace
- The PVC must be accessible (not bound to another running pod)

### Step 1: Identify the Existing Bitnami PVC Name

```console
kubectl get pvc -n <namespace> | grep solr
```

Example output:
```
data-my-release-solr-0   Bound    pvc-xxxx   20Gi   RWO    standard   30d
```

The PVC name is `data-my-release-solr-0`.

### Step 2: Stop the Old Bitnami Solr (if running)

If you have an existing Bitnami Solr deployment, scale it down or delete it (keeping the PVC):

```console
# Scale down the StatefulSet
kubectl scale statefulset <old-release>-solr --replicas=0 -n <namespace>

# Or delete it (PVC will be retained by default)
kubectl delete statefulset <old-release>-solr -n <namespace>
```

### Step 3: Deploy with Migration Enabled

Configure the migration in your values file or via command line:

**Using values.yaml:**
```yaml
solr:
  createCore: true
  coreName: persephone
  migration:
    enabled: true
    bitnamiPvcName: "data-my-release-solr-0"  # Your existing Bitnami PVC name
    debug: false  # Set to true for troubleshooting
```

**Using Helm command line:**
```console
helm upgrade my-release ./charts/webcerberus -n <namespace> \
  --set solr.migration.enabled=true \
  --set solr.migration.bitnamiPvcName=data-my-release-solr-0
```

### Step 4: Verify Migration

Check the init container logs to verify the migration completed successfully:

```console
# Get the pod name
kubectl get pods -n <namespace> | grep solr

# Check the migration container logs
kubectl logs <pod-name> -c migrate-bitnami-data -n <namespace>
```

Successful migration output:
```
=== Bitnami Solr Full Data Migration ===
Source (Bitnami): /bitnami-solr/server/solr
Target (Community Solr): /var/solr/data
Main core: persephone
Migration flag file: .migrated

=== Step 1: Migrate configsets ===
--- Processing configset: persephone ---
  Copying configset...
  ✓ Configset persephone migrated successfully

=== Step 2: Migrate main core (persephone) ===
--- Processing core: persephone ---
  ✓ Source has Lucene index data - proceeding with migration
  Config mode: uses configSet 'persephone'
  ✓ Core persephone migrated successfully

=== Step 3: Migrate user cores (uXXXXXX pattern) ===
--- Processing core: u014154 ---
  ✓ Source has Lucene index data - proceeding with migration
  Config mode: uses configSet 'persephone'
  ✓ Core u014154 migrated successfully
User cores: 15 migrated, 0 skipped (already migrated)

=== Migration Summary ===
Migrated cores (with .migrated flag):
/var/solr/data/configsets/persephone
/var/solr/data/persephone
/var/solr/data/u014154
...
```

### Step 5: (Optional) Keep Migration Enabled for Incremental Updates

Unlike previous versions, you can keep migration enabled even after initial migration. The `.migrated` flag files ensure:

- Already-migrated directories are skipped (fast startup)
- New cores added to Bitnami will be migrated on next restart
- You can selectively re-migrate by removing specific flag files

To disable migration completely:

```yaml
solr:
  migration:
    enabled: false
```

### Troubleshooting Migration

**Enable Debug Mode:**

If migration is not working as expected, enable debug mode to pause the container and allow manual inspection:

```yaml
solr:
  migration:
    enabled: true
    bitnamiPvcName: "data-my-release-solr-0"
    debug: true
    debugSleepSeconds: 3600  # Sleep for 1 hour
```

**Exec into the Container:**
```console
kubectl exec -it <pod-name> -c migrate-bitnami-data -n <namespace> -- /bin/bash

# Inside the container, inspect the mount points:
ls -la /bitnami-solr/server/solr/
ls -la /bitnami-solr/server/solr/configsets/
ls -la /var/solr/data/

# Check a specific core's properties
cat /bitnami-solr/server/solr/u014154/core.properties

# View migration flags
find /var/solr/data -name ".migrated" -exec cat {} \;
```

**Common Issues:**

| Issue | Cause | Solution |
|-------|-------|----------|
| "No Bitnami data found" | PVC not mounted or wrong PVC name | Verify PVC name and that it exists |
| "No index directory found" | Core has no data | Normal - empty cores are skipped |
| Core skipped | `.migrated` flag exists | Remove the flag file to re-migrate |
| "Migration flag found" | Already migrated | Expected behavior - use flag removal for re-migration |
| ConfigSet not found | Core references missing configset | Ensure configsets are migrated first |

**Re-migrate a Specific Core:**

```console
# Remove the flag file
kubectl exec -it <pod-name> -n <namespace> -- rm /var/solr/data/u014154/.migrated

# Restart the pod to trigger migration
kubectl delete pod <pod-name> -n <namespace>
```

**Clean Restart (Full Re-migration):**

If you need to restart the migration from scratch:

```console
# Delete the new Solr resources
kubectl delete statefulset <release>-solr -n <namespace>
kubectl delete pvc solr-data-<release>-solr-0 -n <namespace>

# Redeploy with migration enabled
helm upgrade <release> ./charts/webcerberus -n <namespace> \
  --set solr.migration.enabled=true \
  --set solr.migration.bitnamiPvcName=data-<old-release>-solr-0
```

### Solr Configuration Details

The standalone Solr deployment includes:

- **Custom ConfigMap** (`<release>-solr-config`) containing:
  - `solrconfig.xml` - Solr configuration with ManagedIndexSchemaFactory
  - `managed-schema` - Schema with WebCerberus-specific field types
  - `stopwords.txt`, `synonyms.txt`, `protwords.txt` - Text analysis files
  - `stopwords_en.txt` - English stopwords for `text_en` field type

- **Custom Field Types**:
  - `text_names` - For name fields with edge n-gram tokenization
  - `text_en` - English text with stemming
  - `text_en_splitting` - English text with word delimiter support
  - Standard Solr field types (`string`, `text_general`, etc.)

- **Pre-defined Fields**:
  - `names`, `qual_values`, `qual_name` - Using `text_names` type
  - `description` - Using `text_en` type

### Post-Migration Cleanup

After verifying the migration is successful and the application is working correctly:

1. **Delete the old Bitnami Solr PVC** (optional, to free storage):
   ```console
   kubectl delete pvc data-<old-release>-solr-0 -n <namespace>
   ```

2. **Remove migration configuration** from your values file (optional - safe to keep enabled)

3. **Update any CI/CD pipelines** to use the new Solr configuration

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

 4. The  MariaDB database can be installed in the same namespace from any public repo. Point out the MariaDB version via the image tag 'image.tag=X.Y.Z'. As an example, the MariaDB of version 10.11.10 will be installed by the next command: 

```console
helm install mariadb oci://registry-1.docker.io/bitnamicharts/mariadb --namespace psnspace --set image.tag=10.11.10,architecture=standalone,auth.rootPassword="MySecret1",auth.database=persephone,primary.persistence.enabled=true -f 'A:\Path\To\\mariadb-helm-values.yaml'
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



