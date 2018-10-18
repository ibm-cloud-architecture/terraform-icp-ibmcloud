# Terraform ICP IBM Cloud

This Terraform example configurations uses the [IBM Cloud  provider](https://ibm-cloud.github.io/tf-ibm-docs/index.html) to provision virtual machines on IBM Cloud Infrastructure (SoftLayer)
and [Terraform Module ICP Deploy](https://github.com/ibm-cloud-architecture/terraform-module-icp-deploy) to prepare VSIs and deploy [IBM Cloud Private](https://www.ibm.com/cloud-computing/products/ibm-cloud-private/) version 3.1.0 or later.  This Terraform template automates best practices learned from installing ICP on IBM Cloud Infrastructure.

## Deployment overview
This template creates an environment where
 - Cluster is deployed directly on public network and is accessed on the VMs public IP
 - There are no load balancers, but applications can be accessed via NodePort on public IP of proxy node
 - Most ICP services disabled (some can be activated via `terraform.tfvars` settings as described below)
 - Minimal VM sizes
 - No separate boot node
 - No management node (can be enabled via `terraform.tfvars` settings as described below)
 - No Vulnerability Advisor node and vulnerability advisor service disabled by default

## Architecture Diagram

![Architecture](../../static/icp_ce_minimal.png)

## Pre-requisites

* Working copy of [Terraform](https://www.terraform.io/intro/getting-started/install.html)
  * As of this writing, IBM Cloud Terraform provider is not in the main Terraform repository and must be installed manually.  See [these steps](https://ibm-cloud.github.io/tf-ibm-docs/index.html#using-terraform-with-the-ibm-cloud-provider).  The templates have been tested with Terraform version 0.11.7 and the IBM Cloud provider version 0.11.3.
* The template is tested on VSIs based on Ubuntu 16.04.  RHEL is not supported in this automation.


### Using the Terraform templates

1. git clone the repository

1. Navigate to the template directory `templates/icp-ce-minimal`

1. Create a `terraform.tfvars` file to reflect your environment.  Please see [variables.tf](variables.tf) and below tables for variable names and descriptions.  Here is an example `terraform.tfvars` file:


```
sl_username = "<my username>"
sl_api_key  = "<my api key>"
datacenter  = "dal13"
key_name    = ["my-ssh-key"]
```

1. Run `terraform init` to download depenencies (modules and plugins)

1. Run `terraform plan` to investigate deployment plan

1. Run `terraform apply` to start deployment.


### Automation Notes

#### What does the automation do
1. Create the virtual machines as defined in `variables.tf` and `terraform.tfvars`
   - Use cloud-init to add a user `icpdeploy` with a randomly generated ssh-key
   - Configure a separate hard disk to be used by docker
2. Create security groups and rules for cluster communication as declared in [security_group.tf](security_group.tf)
3. Handover to the [icp-deploy](https://github.com/ibm-cloud-architecture/terraform-module-icp-deploy) terraform module as declared in the [icp-deploy.tf](icp-deploy.tf) file

#### What does the icp deploy module do
1. It uses the provided ssh key which has been generated for the `icpdeploy` user to ssh from the terraform controller to all cluster nodes to install ICP prerequisites
2. It generates a new ssh keypair for ICP Boot(master) node to ICP cluster communication and distributes the public key to the cluster nodes. This key is used by the ICP Ansible installer.
3. It populates the necessary `/etc/hosts` file on the boot node
4. It generates the ICP cluster hosts file based on information provided in [icp-deploy.tf](icp-deploy.tf)
5. It generates the ICP cluster `config.yaml` file based on information provided in [icp-deploy.tf](icp-deploy.tf)

#### Security Groups

The automation leverages Security Groups to lock down public and private access to the cluster.

- SSH is allowed to all cluster nodes to ease exploration and investigation
- UDP and TCP port 30000 - 32767 are allowed on proxy node to enable use of [NodePort](https://www.ibm.com/support/knowledgecenter/en/SSBS6K_3.1.0/manage_applications/expose_app.html)
- Inbound communication to the master node is permitted on [ports relevant to the ICP service](https://www.ibm.com/support/knowledgecenter/en/SSBS6K_3.1.0/supported_system_config/required_ports.html)
- All outbound communication is allowed.
- All other communication is only permitted between cluster nodes.

### Terraform configuration

Please see [variables.tf](variables.tf) for additional parameters.

| name | required                        | value        |
|----------------|------------|--------------|
| `sl_username`   | yes          | Username for IBM Cloud infrastructure account |
| `sl_api_key`   | yes          | API Key for IBM Cloud infrastructure account |
| `key_name`   | no           | Array of SSH keys to add to `root` for all created VSI instances.  Note that the automation generates its own SSH keys so these are additional keys that can be used for access |
| `datacenter`   | yes           | Datacenter to place all objects in |
| `os_reference_code`   | yes           | OS to install on the VSIs.  Use the [API](https://api.softlayer.com/rest/v3/SoftLayer_Virtual_Guest_Block_Device_Template_Group/getVhdImportSoftwareDescriptions.json?objectMask=referenceCode) to determine valid values. Only Ubuntu 16.04 was tested. Note that the boot node OS can be specified separately (defaults to `UBUNTU_16_64` to save licensing costs). |
| `icp_inception_image` | no | The ICP installer image to use.  This corresponds to the version of ICP to install. Defaults to 3.1.0 |
| `docker_package_location` | no | The local path to where the IBM-provided docker installation binary is saved. If not specified and using Ubuntu, will install latest `docker-ce` off public repo. |
| `private_network_only` | no | Specify true to remove the cluster from the public network. If public network access is disabled, note that to allow outbound internet access you will require a Gateway Appliance on the VLAN to do Source NAT. Additionally, the automation requires SSH access to the boot node to provision ICP, so a VPN tunnel may be required.  The LBaaS for both the master and the control plane will still be provisioned on the public internet, but the cluster nodes will not have public addresses configured. |
| `private_vlan_router_hostname` | no | Private VLAN router to place all VSIs behind.  e.g. bcr01a. See Network > IP Management > VLANs in the portal. Leave blank to let the system choose. This option should be used when setting `private_network_only` to true along with `private_vlan_number` using a private VLAN that is routed with a Gateway Appliance. |
| `private_vlan_number` | no | Private VLAN number to place all VSIs on.  e.g. 1211. See Network > IP Management > VLANs in the portal. Leave blank to let the system choose. This option should be used when setting `private_network_only` to true along with `private_vlan_router_hostname`, using a private VLAN that is routed with a Gateway Appliance.|
| `public_vlan_router_hostname` | no | Public VLAN router to place all VSIs behind.  e.g. fcr01a. See Network > IP Management > VLANs in the portal. Leave blank to let the system choose. |
| `public_vlan_number` | no | Public VLAN number to place all VSIs on.  e.g. 1211. See Network > IP Management > VLANs in the portal. Leave blank to let the system choose. |
| `icppassword` | no | ICP administrator password.  One will be generated if not set. |
| `deployment` | no | Identifier prefix added to the host names of all your infrastructure resources for organising/naming ease |

### Configuration examples

1. terraform.tfvars which does not add a SSH key and uses all default values. This is the minimum configuration possible.

    ```
    sl_username = "<my username>"
    sl_api_key  = "<my api key>"
    datacenter  = "dal13"
    ```

2. terraform.tfvars which adds a SSH key to the root user and uses all default values.

    ```
    sl_username = "<my username>"
    sl_api_key  = "<my api key>"
    datacenter  = "dal13"
    key_name    = ["my-ssh-key"]
    ```

3. terraform.tfvars which adds a management node and some additional services (metering, monitoring and logging)

    ```
    sl_username = "<my username>"
    sl_api_key  = "<my api key>"
    key_name    = ["my-ssh-key"]

    # Disable most management services except metering, monitoring and logging
    disabled_management_services = ["istio", "vulnerability-advisor", "storage-glusterfs", "storage-minio", "custom-metrics-adapter", "image-security-enforcement"]

    # Enabling metering, monitoring and logging requires additinal resources,
    # so we will enable 1 dedicated management node
    mgmt        = {
      nodes = "1"
    }

    ```

4. terraform.tfvars which adds additional worker nodes, a management node and some additional services (metering, monitoring and logging)

    ```
    sl_username = "<my username>"
    sl_api_key  = "<my api key>"
    key_name    = ["my-ssh-key"]

    # Disable most management services except metering, monitoring and logging
    disabled_management_services = ["istio", "vulnerability-advisor", "storage-glusterfs", "storage-minio", "custom-metrics-adapter", "image-security-enforcement"]

    # Enabling metering, monitoring and logging requires additinal resources,
    # so we will enable 1 dedicated management node
    mgmt        = {
      nodes = "1"
    }
    worker        = {
      nodes = "6"
    }

    ```
