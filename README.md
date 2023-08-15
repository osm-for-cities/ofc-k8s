# Kubernetes infrastructure for OSM for cities.

This container holds the configuration for deploying a Kubernetes infrastructure for hosting the OSM-for-Cities platform.


# Install cluster

```sh
./deploy production create
```

# Delete cluster

```sh
./deploy production delete
```

### Select instances for spot deployment

Choose the available instances in the region and update the `nodeGroups.yaml` with the appropriate node configurations.

```sh
ec2-instance-selector --vcpus-to-memory-ratio 1:4 --vcpus=8 --gpus 0 --current-generation -a x86_64 --deny-list '.*n.*|.*d.*'   --region us-west-1
```