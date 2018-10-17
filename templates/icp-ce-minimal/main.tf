provider "ibm" {
    softlayer_username = "${var.sl_username}"
    softlayer_api_key = "${var.sl_api_key}"
}

locals {
   icppassword    = "${var.icppassword != "" ? "${var.icppassword}" : "${random_id.adminpassword.hex}"}"

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


data "ibm_compute_ssh_key" "public_key" {
  count = "${length(var.key_name)}"
  label = "${element(var.key_name, count.index)}"
}

# Generate a random string in case user wants us to generate admin password
resource "random_id" "adminpassword" {
  byte_length = "16"
}
