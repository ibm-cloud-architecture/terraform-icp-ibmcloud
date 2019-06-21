##### SoftLayer/IBMCloud Access Credentials ######

variable "key_name" {
  description = "Name or reference of SSH key to provision IBM Cloud instances with"
  default = []
}

variable "deployment" {
   description = "Identifier prefix added to the host names."
   default = "icp"
}

variable "os_image" {
  description = "IBM Cloud OS reference code to determine OS, version, word length"
  default = "ubuntu-16.04-amd64"
}

variable "vpc_region" {
  default   = "us-south"
}

variable "vpc_address_prefix" {
  description = "address prefixes for each zone in the VPC.  the VPC subnet CIDRs for each zone must be within the address prefix."
  default = [ "10.10.0.0/24", "10.11.0.0/24", "10.12.0.0/24" ]
}

variable "vpc_subnet_cidr" {
  default = [ "10.10.0.0/24", "10.11.0.0/24", "10.12.0.0/24" ]
}

##### ICP Instance details ######

variable "boot" {
  type = "map"

  default = {
    profile           = "cc1-2x4"

    disk_size         = "100" // GB
    docker_vol_size   = "100" // GB

    network_speed     = "1000"
  }
}

variable "master" {
  type = "map"

  default = {
    nodes             = "3"
    profile           = "cc1-8x16"

    disk_size         = "100" // GB
    docker_vol_size   = "100" // GB

    network_speed     = "1000"
  }
}

variable "mgmt" {
  type = "map"

  default = {
    nodes       = "3"
    profile           = "bc1-4x16"

    disk_size         = "100" // GB
    docker_vol_size   = "100" // GB

    network_speed = "1000"
  }
}

variable "proxy" {
  type = "map"

  default = {
    nodes       = "3"

    profile           = "cc1-2x4"

    disk_size         = "100" // GB
    docker_vol_size   = "100" // GB

    network_speed= "1000"
  }
}

variable "va" {
  type = "map"

  default = {
    nodes       = "0"

    profile           = "bc1-4x16"

    disk_size         = "100" // GB
    docker_vol_size   = "100" // GB

    network_speed = "1000"
  }
}


variable "worker" {
  type = "map"

  default = {
    nodes       = "3"

    profile           = "bc1-4x16"

    disk_size         = "100" // GB, 25 or 100
    docker_vol_size   = "100" // GB
    additional_disk   = "0"   // GB, if you want an additional block device, set to non-zero

    network_speed= "1000"
  }
}

variable "docker_package_location" {
  description = "URI for docker package location, e.g. http://<myhost>/icp-docker-17.09_x86_64.bin or nfs:<myhost>/icp-docker-17.09_x86_64.bin"
  default     = ""
}

variable "image_location" {
  description = "URI for image package location, e.g. http://<myhost>/ibm-cloud-private-x86_64-2.1.0.2.tar.gz or nfs:<myhost>/ibm-cloud-private-x86_64-2.1.0.2.tar.gz"
  default     = ""
}

variable "image_location_user" {
  description = "Username if required by image_location i.e. authenticated http source"
  default     = ""
}

variable "image_location_password" {
  description = "Password if required by image_location i.e. authenticated http source"
  default     = ""
}

variable "icppassword" {
  description = "Password for the initial admin user in ICP; blank to generate"
  default     = ""
}

variable "icp_inception_image" {
  description = "ICP image to use for installation"
  default     = "ibmcom/icp-inception-amd64:3.1.0-ee"
}

variable "cluster_cname" {
  default = ""
}

variable "registry_server" {
  default   = ""
}

variable "registry_username" {
  default   = ""
}

variable "registry_password" {
  default   = ""
}


variable "pod_network_cidr" {
  description = "Pod network CIDR "
  default     = "172.20.0.0/16"
}

variable "service_network_cidr" {
  description = "Service network CIDR "
  default     = "172.21.0.0/16"
}

# The following services can be disabled for 3.1
# custom-metrics-adapter, image-security-enforcement, istio, metering, monitoring, service-catalog, storage-minio, storage-glusterfs, and vulnerability-advisor
# TODO: because VPC does not have shared storage, we disabled the image-manager so that installation completes successfully.. Future implementations we may stand up stand-alone gluster, ceph, or nfs.
variable "disabled_management_services" {
  description = "List of management services to disable"
  type        = "list"
  default     = ["istio", "vulnerability-advisor", "storage-glusterfs", "storage-minio", "image-manager"]
}


