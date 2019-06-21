# Terraform ICP IBM Cloud

This Terraform example configurations uses the [IBM Cloud provider](https://ibm-cloud.github.io/tf-ibm-docs/index.html) to provision virtual machines on IBM Cloud Infrastructure (SoftLayer)
and [Terraform Module ICP Deploy](https://github.com/ibm-cloud-architecture/terraform-module-icp-deploy) to prepare VSIs and deploy [IBM Cloud Private](https://www.ibm.com/cloud-computing/products/ibm-cloud-private/) version 3.1.0 or later in a Highly Available configuration.  This Terraform template automates best practices learned from installing ICP on IBM Cloud Infrastructure.

## Deployment overview
This template creates an environment where
 - Cluster is deployed on [IBM Virtual Private Cloud (VPC)](https://cloud.ibm.com/docs/vpc-on-classic?topic=vpc-on-classic-about) private network and is accessed through load balancers
 - The cluster is deployed in a single region across three zones, each zone has its own subnet
 - Dedicated management node(s)
 - Dedicated boot node
 - SSH access from public network is enabled on boot node only
 - Optimised VM sizes
 - Image Manager is disabled due to lack of File Storage (TODO)
 - No Vulnerability Advisor node and vulnerability advisor service disabled by default (can be enabled via `terraform.tfvars` settings as described below)
 - The images must be pushed to a remote registry and installed over the internet.

## Pre-requisites

* Working copy of [Terraform](https://www.terraform.io/intro/getting-started/install.html)
  * As of this writing, IBM Cloud Terraform provider is not in the main Terraform repository and must be installed manually.  See [these steps](https://ibm-cloud.github.io/tf-ibm-docs/index.html#using-terraform-with-the-ibm-cloud-provider).  The templates have been tested with Terraform version 0.11.11 and the IBM Cloud provider version 0.17.1.
* The template is tested on VSIs based on Ubuntu 16.04.  RHEL is not supported in this automation.

### Environment preparation

The images must be pushed to a remote registry and installed over the internet.  One possibilities are to use the IBM Cloud Registry.   Acquire the binary tarball for IBM Cloud Private, and follow [these instructions](https://cloud.ibm.com/docs/services/Registry?topic=registry-getting-started) to create a namespace in the IBM Cloud Registry. 

Use `docker login` to authenticate to the registry.  The following example commands to load the images locally and push them to the IBM Cloud Registry.

```bash
# load all the images locally
tar xf ibm-cloud-private-x86_64-3.2.0.tar.gz -O | docker load

# tag the images with the ICR registry URL and namespace
docker images | grep -v "TAG" | grep -v harbor  | awk '{a = $1; b =  sub(/ibmcom/,"<namespace>",a); print "docker tag " $1 ":" $2 " <region>.icr.io/" a ":" $2 }'

# remove the arch from the image names
images=`docker images | grep <region>.icr.io | grep -v "TAG" | awk '{print $1 ":" $2}' | grep amd64`
for image in $images; do docker tag $image `echo $image | sed -e 's/-amd64//'`; done

# push all the images to ICR
docker images | grep <region>.icr.io | grep -v "TAG" | awk '{print $1 ":" $2}'  | xargs -n1 docker push 
```

Once this is complete you can configure the ICP installation to pull images from the repository by first [creating an API key for read-only access](https://cloud.ibm.com/docs/services/Registry?topic=registry-registry_access), then setting the following variables before running the terraform:

```
registry_server = "<region>.icr.io"
registry_username = "iamapikey"
registry_password = "<apikey>"
icp_inception_image = "<namespace>/icp-inception:3.2.0-ee"
```


### Using the Terraform templates

1. git clone the repository

2. Navigate to the template directory `templates/icp-ee-vpc`

3. Create a `terraform.tfvars` file to reflect your environment.  Please see [variables.tf](variables.tf) and below tables for variable names and descriptions.  Here is an example `terraform.tfvars` file:

```
key_name = ["jkwong-pub"]
deployment = "icp"
icp_inception_image = "ibmcom/icp-inception:3.2.0-ee"
registry_server = "<region>.icr.io"
registry_username = "iamapikey"
registry_password = "<my api key>"

network_cidr = "172.24.0.0/16"
service_network_cidr = "172.25.0.0/16"

master = {
  nodes = "3"
  cpu_cores         = "8"
  memory            = "32768"
}

proxy = {
  nodes = "3"
}

worker = {
  nodes = "3"
}

mgmt = {
  nodes = "3"
}

va = {
  nodes = "0"
}
```

1. Export the API keys to the environment

   ```bash
   export BM_API_KEY=<IBM Cloud API key>
   ```

2. Run `terraform init` to download depenencies (modules and plugins)

3. Run `terraform plan` to investigate deployment plan

4. Run `terraform apply` to start deployment.


### Automation Notes

#### What does the automation do
1. Create a VPC in a region
2. Create subnets for each zone in the region
3. Create public gateways for each subnet
5. Create security groups and rules for cluster communication as declared in [security_group.tf](security_group.tf)
6. Create load balancers for Proxy and Control plane
7. Create a boot node and assign it a floating IP
8. Create the virtual machines as defined in `variables.tf` and `terraform.tfvars`
   - Use cloud-init to add a user `icpdeploy` with a randomly generated ssh-key
   - Configure a separate hard disk to be used by docker
   - Configure the shared storage on master nodes

9. Handover to the [icp-deploy](https://github.com/ibm-cloud-architecture/terraform-module-icp-deploy) terraform module as declared in the [icp-deploy.tf](icp-deploy.tf) file


#### What does the icp deploy module do
1. It uses the provided ssh key which has been generated for the `icpdeploy` user to ssh from the terraform controller to all cluster nodes to install ICP prerequisites
2. It generates a new ssh keypair for ICP Boot(master) node to ICP cluster communication and distributes the public key to the cluster nodes. This key is used by the ICP Ansible installer.
3. It populates the necessary `/etc/hosts` file on the boot node
4. It generates the ICP cluster hosts file based on information provided in [icp-deploy.tf](icp-deploy.tf)
5. It generates the ICP cluster `config.yaml` file based on information provided in [icp-deploy.tf](icp-deploy.tf)

#### Security Groups

The automation leverages Security Groups to lock down public and private access to the cluster.

- Inbound communication to the master and proxy nodes are only permitted on ports from the private subnet that the LBaaS is provisioned on.
- Inbound SSH to the boot node is permitted from all addresses on the internet.
- All outbound communication is allowed.
- All other communication is only permitted between cluster nodes.

#### LBaaS

The automation exposes the Master control plane to the Internet on:
- TCP port 8443 (master console)
- TCP port 8500 (private registry)
- TCP port 8600 (private registry)
- TCP port 8001 (Kubernetes API)
- TCP port 9443 (OIDC authentication endpoint)

The automation exposes the Proxy nodes to the internet on:
- TCP port 443 (https)
- TCP port 80 (http)

### Terraform configuration

Please see [variables.tf](variables.tf) for additional parameters.

