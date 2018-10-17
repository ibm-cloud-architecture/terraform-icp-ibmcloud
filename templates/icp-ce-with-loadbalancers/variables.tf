##### SoftLayer/IBMCloud Access Credentials ######

# Provide values for these in terraform.tfvars
variable "sl_username" { description = "IBM Cloud (aka SoftLayer) user name." }
variable "sl_api_key" { description = "IBM Cloud (aka SoftLayer) API key." }

variable "key_name" {
  description = "Name or reference of SSH key to provision IBM Cloud instances with"
  default = []
}

##### Common VM specifications ######
# Provide values for these in terraform.tfvars
variable "datacenter" { }

variable "private_vlan_router_hostname" {
   default = ""
   description = "Private VLAN router to place all VMs behind.  e.g. bcr01a. See Network > IP Management > VLANs in the portal. Leave blank to let the system choose."
}

variable "private_vlan_number" {
   default = -1
   description = "Private VLAN number to place all VMs on.  e.g. 1211. See Network > IP Management > VLANs in the portal. Leave blank to let the system choose."
}

variable "public_vlan_router_hostname" {
   default = ""
   description = "Public VLAN router to place all VMs behind.  e.g. fcr01a. See Network > IP Management > VLANs in the portal. Leave blank to let the system choose."
}

variable "public_vlan_number" {
   default = -1
   description = "Public VLAN number to place all VMs on.  e.g. 1171. See Network > IP Management > VLANs in the portal. Leave blank to let the system choose."
}

variable "deployment" {
   description = "Identifier prefix added to the host names."
   default = "icptest"
}

variable "os_reference_code" {
  description = "IBM Cloud OS reference code to determine OS, version, word length"
  default = "UBUNTU_16_64"
}

variable "domain" {
  description = "Specify domain name to be used for linux customization on the VMs, or leave blank to use <deployment>.icp"
  default     = ""
}

variable "private_network_only" {
  description = "Specify false to place the cluster on the public network. If public network access is disabled, you will require a NAT gateway device like a Gateway Appliance on the VLAN."
  default = false
}

##### ICP Instance details ######

variable "boot" {
  type = "map"

  default = {
    nodes             = "0"
    cpu_cores         = "2"
    memory            = "4096"

    disk_size         = "100" // GB
    docker_vol_size   = "100" // GB
    local_disk        = true
    os_reference_code = "UBUNTU_16_64"

    network_speed     = "1000"

    hourly_billing = true
  }
}

variable "master" {
  type = "map"

  default = {
    nodes             = "1"

    cpu_cores         = "8"
    memory            = "16384"

    disk_size         = "100" // GB
    docker_vol_size   = "100" // GB
    local_disk        = false

    network_speed     = "1000"

    hourly_billing = true
  }
}

variable "mgmt" {
  type = "map"

  default = {
    nodes       = "0"

    cpu_cores   = "4"
    memory      = "16384"

    disk_size         = "100" // GB
    docker_vol_size   = "100" // GB
    local_disk  = false

    network_speed = "1000"

    hourly_billing=true
  }
}

variable "proxy" {
  type = "map"

  default = {
    nodes       = "1"

    cpu_cores   = "2"
    memory      = "4096"

    disk_size         = "100" // GB
    docker_vol_size   = "100" // GB
    local_disk  = false

    network_speed= "1000"

    hourly_billing = true
  }
}

variable "va" {
  type = "map"

  default = {
    nodes       = "0"

    cpu_cores   = "4"
    memory      = "8192"

    disk_size         = "100" // GB
    docker_vol_size   = "100" // GB
    local_disk  = false

    network_speed = "1000"

    hourly_billing = true
  }
}


variable "worker" {
  type = "map"

  default = {
    nodes       = "3"

    cpu_cores   = "4"
    memory      = "4096"

    disk_size         = "100" // GB
    docker_vol_size   = "100" // GB
    local_disk  = false

    network_speed= "1000"

    hourly_billing = true
  }
}

variable "icppassword" {
  description = "Password for the initial admin user in ICP; blank to generate"
  default     = ""
}

variable "icp_inception_image" {
  description = "ICP image to use for installation"
  default     = "ibmcom/icp-inception:3.1.0"
}

variable "network_cidr" {
  description = "Pod network CIDR "
  default     = "172.20.0.0/16"
}

variable "service_network_cidr" {
  description = "Service network CIDR "
  default     = "172.21.0.0/16"
}

# The following services can be disabled for 3.1
# custom-metrics-adapter, image-security-enforcement, istio, metering, monitoring, service-catalog, storage-minio, storage-glusterfs, and vulnerability-advisor
variable "disabled_management_services" {
  description = "List of management services to disable"
  type        = "list"
  default     = ["istio", "vulnerability-advisor", "storage-glusterfs", "storage-minio", "metrics-server", "custom-metrics-adapter", "image-security-enforcement", "metering", "monitoring", "logging", "audit-logging"]
}
