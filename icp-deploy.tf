locals {
    registry_split = "${split("@", var.icp_inception_image)}"
    registry_creds = "${length(local.registry_split) > 1 ? "${element(local.registry_split, 0)}" : ""}"
    image          = "${length(local.registry_split) > 1 ? "${replace(var.icp_inception_image, "/.*@/", "")}" : "${var.icp_inception_image}" }"
    icppassword    = "${var.icppassword != "" ? "${var.icppassword}" : "${random_id.adminpassword.hex}"}"
}

##################################
### Deploy ICP to cluster
##################################
module "icpprovision" {
    source = "github.com/jkwong888/terraform-module-icp-deploy.git"

    # Provide IP addresses for boot, master, mgmt, va, proxy and workers
    boot-node = "${ibm_compute_vm_instance.icp-boot.ipv4_address_private}"
    bastion_host  = "${var.private_network_only ? ibm_compute_vm_instance.icp-boot.ipv4_address_private : ibm_compute_vm_instance.icp-boot.ipv4_address}"
    icp-host-groups = {
        master = ["${ibm_compute_vm_instance.icp-master.*.ipv4_address_private}"]
        proxy = ["${ibm_compute_vm_instance.icp-proxy.*.ipv4_address_private}"]
        worker = ["${ibm_compute_vm_instance.icp-worker.*.ipv4_address_private}"]
        management = ["${ibm_compute_vm_instance.icp-mgmt.*.ipv4_address_private}"]
        va = ["${ibm_compute_vm_instance.icp-va.*.ipv4_address_private}"]
    }

    # Provide desired ICP version to provision
    icp-version = "${local.inception_image}"

    # TODO: Need to correct spelling of parallel in terraform-icp-deploy variables.tf, main.tf and where-ever else.
    parallell-image-pull = true

    /* Workaround for terraform issue #10857
     When this is fixed, we can work this out automatically */
    cluster_size  = "${1 + var.master["nodes"] + var.worker["nodes"] + var.proxy["nodes"] + var.mgmt["nodes"] + var.va["nodes"]}"

    ###################################################################################################################################
    ## You can feed in arbitrary configuration items in the icp_configuration map.
    ## Available configuration items availble from https://www.ibm.com/support/knowledgecenter/SSBS6K_2.1.0/installing/config_yaml.html
    icp_config_file = "./icp-config.yaml"
    icp_configuration = {
      "network_cidr"                    = "${var.network_cidr}"
      "service_cluster_ip_range"        = "${var.service_network_cidr}"
      "cluster_lb_address"              = "${var.master["nodes"] > 1 ? "${ibm_lbaas.master-lbaas.vip}" : ""}"
      "proxy_lb_address"                = "${var.proxy["nodes"] > 1 ? "${ibm_lbaas.proxy-lbaas.vip}" : ""}"
      "cluster_CA_domain"               = "${var.master["nodes"] > 1 ? ibm_lbaas.master-lbaas.vip : ""}"
      "cluster_name"                    = "${var.deployment}"
      "calico_ip_autodetection_method"  = "interface=eth0"
      "default_admin_password"          = "${local.icppassword}"
      "disabled_management_services"    = [
          "${var.va["nodes"] == 0 ? "va" : "" }",
          "${var.va["nodes"] == 0 ? "vulnerability-advisor" : "" }"
      ]
      "image_repo"                      = "${dirname(local.image)}"
      "private_registry_enabled"        = "${local.registry_creds != "" ? "true" : "false" }"
      "private_registry_server"         = "${local.registry_creds != "" ? "${dirname(dirname(local.image))}" : "" }"
      "docker_username"                 = "${local.registry_creds != "" ? "${replace(local.registry_creds, "/:.*/", "")}" : "" }"
      "docker_password"                 = "${local.registry_creds != "" ? "${replace(local.registry_creds, "/.*:/", "")}" : "" }"
    }

    # We will let terraform generate a new ssh keypair
    # for boot master to communicate with worker and proxy nodes
    # during ICP deployment
    generate_key = true

    # SSH user and key for terraform to connect to newly created VMs
    # ssh_key is the private key corresponding to the public assumed to be included in the template
    ssh_user        = "icpdeploy"
    ssh_key_base64  = "${base64encode(tls_private_key.installkey.private_key_pem)}"
    ssh_agent       = false
}

output "ICP Console load balancer DNS (external)" {
  value = "${element(ibm_lbaas.master-lbaas.*.vip, 0)}"
}

output "ICP Proxy load balancer DNS (external)" {
  value = "${element(ibm_lbaas.proxy-lbaas.*.vip, 0)}"
}

output "ICP Console URL" {
  value = "https://${element(ibm_lbaas.master-lbaas.*.vip, 0)}:8443"
}

output "ICP Registry URL" {
  value = "${element(ibm_lbaas.master-lbaas.*.vip, 0)}:8500"
}

output "ICP Kubernetes API URL" {
  value = "https://${element(ibm_lbaas.master-lbaas.*.vip, 0)}:8001"
}

output "ICP Admin Username" {
  value = "admin"
}

output "ICP Admin Password" {
  value = "${local.icppassword}"
}
