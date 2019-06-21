provider "ibm" {
  generation = "1"
}

locals {
  # Set the local filename of the docker package if we're uploading it
  docker_package_uri = "${var.docker_package_location != "" ? "/tmp/${basename(var.docker_package_location)}" : "" }"

  # The storage IDs that will be
  master_fs_ids = "${compact(
      concat(
        ibm_storage_file.fs_audit.*.id,
        ibm_storage_file.fs_registry.*.id,
        list(""))
    )}"

    icppassword    = "${var.icppassword != "" ? "${var.icppassword}" : "${random_id.adminpassword.hex}"}"


    #######
    ## Intermediate interpolations for the private registry
    ## Whether we are provided with details of an external, or we create one ourselves
    ## the image_repo and docker_username / docker_password will always be available and consistent
    #######

    # If we stand up a image registry what will the registry_server name and namespace be
    registry_server = "${var.registry_server != "" ? "${var.registry_server}" : ""}"
    namespace       = "${dirname(var.icp_inception_image)}" # This will typically return ibmcom

    # The final image repo will be either interpolated from what supplied in icp_inception_image or
    image_repo      = "${var.registry_server == "" ? "" : "${local.registry_server}/${local.namespace}"}"
    icp-version     = "${format("%s%s%s", "${local.docker_username != "" ? "${local.docker_username}:${local.docker_password}@" : ""}",
                        "${var.registry_server != "" ? "${var.registry_server}/" : ""}",
                        "${var.icp_inception_image}")}"

    # If we're using external registry we need to be supplied registry_username and registry_password
    docker_username = "${var.registry_username != "" ? var.registry_username : ""}"
    docker_password = "${var.registry_password != "" ? var.registry_password : ""}"

    # This is just to have a long list of disabled items to use in icp-deploy.tf
    disabled_list = "${list("disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled")}"

    disabled_management_services = "${zipmap(var.disabled_management_services, slice(local.disabled_list, 0, length(var.disabled_management_services)))}"
}

# Create a unique random clusterid for this cluster
resource "random_id" "clusterid" {
  byte_length = "4"
}

# Create a SSH key for SSH communication from terraform to VMs
resource "tls_private_key" "installkey" {
  algorithm   = "RSA"
}

data "ibm_is_ssh_key" "public_key" {
  count = "${length(var.key_name)}"
  name = "${element(var.key_name, count.index)}"
}

resource "ibm_is_ssh_key" "installkey" {
  name = "${format("icp-%s", random_id.clusterid.hex)}"
  public_key = "${tls_private_key.installkey.public_key_openssh}"
}

# Generate a random string in case user wants us to generate admin password
resource "random_id" "adminpassword" {
  byte_length = "16"
}


