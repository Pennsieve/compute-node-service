## Compute Node Service

To build image locally:

`docker build -t pennsieve/compute-node-provisioner .`

To run container:

`docker run --env-file ./env.dev --name compute-node-provisioner pennsieve/compute-node-provisioner`