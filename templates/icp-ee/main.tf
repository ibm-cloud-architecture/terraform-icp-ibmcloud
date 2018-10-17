provider "ibm" {
    softlayer_username = "${var.sl_username}"
    softlayer_api_key = "${var.sl_api_key}"
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
    registry_server = "${var.deployment}-boot-${random_id.clusterid.hex}.${var.domain}"
    namespace       = "${dirname(var.icp_inception_image)}" # This will typically return ibmcom

    # The final image repo will be either interpolated from what supplied in icp_inception_image or
    image_repo      = "${var.image_location == "" ? dirname(var.icp_inception_image) : "${local.registry_server}/${local.namespace}"}"

    # If we're using external registry we need to be supplied registry_username and registry_password
    docker_username = "${var.registry_username != "" ? var.registry_username : "icpdeploy"}"
    docker_password = "${var.registry_password != "" ? var.registry_password : "${local.icppassword}"}"

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

# Create certificates for secure docker registry
# Needed if we are supplied a tarball.
resource "tls_private_key" "registry_key" {
  algorithm = "RSA"
  rsa_bits = "4096"
}

resource "tls_self_signed_cert" "registry_cert" {
  key_algorithm   = "RSA"
  private_key_pem = "${tls_private_key.registry_key.private_key_pem}"

  subject {
    common_name  = "${var.deployment}-boot-${random_id.clusterid.hex}.${var.domain}"
  }

  dns_names  = ["${var.deployment}-boot-${random_id.clusterid.hex}.${var.domain}"]
  validity_period_hours = "${24 * 365 * 10}"

  allowed_uses = [
    "server_auth"
  ]
}




data "ibm_compute_ssh_key" "public_key" {
  count = "${length(var.key_name)}"
  label = "${element(var.key_name, count.index)}"
}

# Generate a random string in case user wants us to generate admin password
resource "random_id" "adminpassword" {
  byte_length = "16"
}
