##################################
### Deploy ICP to cluster
##################################
module "icpprovision" {
    source = "github.com/ibm-cloud-architecture/terraform-module-icp-deploy.git?ref=2.3.5"

    # Provide IP addresses for boot, master, mgmt, va, proxy and workers
    boot-node = "${ibm_compute_vm_instance.icp-master.ipv4_address_private}"
    bastion_host  = "${ibm_compute_vm_instance.icp-master.ipv4_address}"
    icp-host-groups = {
        master = ["${ibm_compute_vm_instance.icp-master.*.ipv4_address_private}"]
        proxy = ["${ibm_compute_vm_instance.icp-proxy.*.ipv4_address_private}"]
        worker = ["${ibm_compute_vm_instance.icp-worker.*.ipv4_address_private}"]
        management = ["${ibm_compute_vm_instance.icp-mgmt.*.ipv4_address_private}"]
        va = ["${ibm_compute_vm_instance.icp-va.*.ipv4_address_private}"]
    }

    # Provide desired ICP version to provision
    icp-version = "${var.icp_inception_image}"

    /* Workaround for terraform issue #10857
     When this is fixed, we can work this out automatically */
    cluster_size  = "${var.master["nodes"] + var.worker["nodes"] + var.proxy["nodes"] + var.mgmt["nodes"] + var.va["nodes"]}"

    ###################################################################################################################################
    ## You can feed in arbitrary configuration items in the icp_configuration map.
    ## Available configuration items availble from https://www.ibm.com/support/knowledgecenter/SSBS6K_3.1.0/installing/config_yaml.html
    icp_configuration = {
      "network_cidr"                    = "${var.network_cidr}"
      "service_cluster_ip_range"        = "${var.service_network_cidr}"
      "cluster_lb_address"              = "${ibm_lbaas.master-lbaas.vip}"
      "proxy_lb_address"                = "${ibm_lbaas.proxy-lbaas.vip}"
      "cluster_CA_domain"               = "${ibm_lbaas.master-lbaas.vip}"
      "cluster_name"                    = "${var.deployment}"
      "calico_ip_autodetection_method"  = "interface=eth0"

      # An admin password will be generated if not supplied in terraform.tfvars
      "default_admin_password"          = "${local.icppassword}"

      # This is the list of disabled management services
      "management_services"             = "${local.disabled_management_services}"
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
  value = "${ibm_lbaas.master-lbaas.vip}"
}

output "ICP Proxy load balancer DNS (external)" {
  value = "${ibm_lbaas.proxy-lbaas.vip}"
}

output "ICP Console URL" {
  value = "https://${ibm_lbaas.master-lbaas.vip}:8443"
}

output "ICP Registry URL" {
  value = "${ibm_lbaas.master-lbaas.vip}:8500"
}

output "ICP Kubernetes API URL" {
  value = "https://${ibm_lbaas.master-lbaas.vip}:8001"
}

output "ICP Admin Username" {
  value = "admin"
}

output "ICP Admin Password" {
  value = "${local.icppassword}"
}
