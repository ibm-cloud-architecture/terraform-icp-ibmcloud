resource "ibm_security_group" "cluster_private" {
  name = "${var.deployment}-cluster-priv-${random_id.clusterid.hex}"
  description = "allow intercluster communication"
}

resource "ibm_security_group_rule" "allow_ingress_from_self_priv" {
  direction = "ingress"
  ether_type = "IPv4"
  remote_group_id = "${ibm_security_group.cluster_private.id}"
  security_group_id = "${ibm_security_group.cluster_private.id}"
}

resource "ibm_security_group_rule" "allow_cluster_egress_private" {
  direction = "egress"
  ether_type = "IPv4"
  security_group_id = "${ibm_security_group.cluster_private.id}"
}

resource "ibm_security_group" "cluster_public" {
  count = "${var.private_network_only ? 0 : 1}"
  name = "${var.deployment}-cluster-pub-${random_id.clusterid.hex}"
  description = "allow intercluster communication"
}

resource "ibm_security_group_rule" "allow_ingress_from_self_pub" {
  count = "${var.private_network_only ? 0 : 1}"
  direction = "ingress"
  ether_type = "IPv4"
  remote_group_id = "${ibm_security_group.cluster_public.id}"
  security_group_id = "${ibm_security_group.cluster_public.id}"
}

resource "ibm_security_group_rule" "allow_cluster_public" {
  count = "${var.private_network_only ? 0 : 1}"
  direction = "egress"
  ether_type = "IPv4"
  security_group_id = "${ibm_security_group.cluster_public.id}"
}

resource "ibm_security_group" "master_group" {
  name = "${var.deployment}-master-${random_id.clusterid.hex}"
  description = "allow incoming to master"
}

# restrict incoming on ports to LBaaS private subnet
resource "ibm_security_group_rule" "allow_port_8443" {
  direction = "ingress"
  ether_type = "IPv4"
  protocol = "tcp"
  port_range_min = 8443
  port_range_max = 8443
  remote_ip = "${ibm_compute_vm_instance.icp-master.0.private_subnet}"
  security_group_id = "${ibm_security_group.master_group.id}"
}

# restrict to LBaaS private subnet
resource "ibm_security_group_rule" "allow_port_8500" {
  direction = "ingress"
  ether_type = "IPv4"
  protocol = "tcp"
  port_range_min = 8500
  port_range_max = 8500
  remote_ip = "${ibm_compute_vm_instance.icp-master.0.private_subnet}"
  security_group_id = "${ibm_security_group.master_group.id}"
}

# restrict to LBaaS private subnet
resource "ibm_security_group_rule" "allow_port_8600" {
  direction = "ingress"
  ether_type = "IPv4"
  protocol = "tcp"
  port_range_min = 8600
  port_range_max = 8600
  remote_ip = "${ibm_compute_vm_instance.icp-master.0.private_subnet}"
  security_group_id = "${ibm_security_group.master_group.id}"
}

# TODO restrict to LBaaS private subnet
resource "ibm_security_group_rule" "allow_port_8001" {
  direction = "ingress"
  ether_type = "IPv4"
  protocol = "tcp"
  port_range_min = 8001
  port_range_max = 8001
  remote_ip = "${ibm_compute_vm_instance.icp-master.0.private_subnet}"
  security_group_id = "${ibm_security_group.master_group.id}"
}


# restrict to LBaaS private subnet
resource "ibm_security_group_rule" "allow_port_9443" {
  direction = "ingress"
  ether_type = "IPv4"
  protocol = "tcp"
  port_range_min = 9443
  port_range_max = 9443
  remote_ip = "${ibm_compute_vm_instance.icp-master.0.private_subnet}"
  security_group_id = "${ibm_security_group.master_group.id}"
}

resource "ibm_security_group_rule" "master_node_allow_outbound_public" {
  direction = "egress"
  ether_type = "IPv4"
  security_group_id = "${ibm_security_group.master_group.id}"
}

# restrict to LBaaS private subnet
resource "ibm_security_group_rule" "allow_port_80" {
  direction = "ingress"
  ether_type = "IPv4"
  protocol = "tcp"
  port_range_min = 80
  port_range_max = 80
  remote_ip = "${ibm_compute_vm_instance.icp-proxy.0.private_subnet}"
  security_group_id = "${ibm_security_group.proxy_group.id}"
}

# restrict to LBaaS private subnet
resource "ibm_security_group_rule" "allow_port_443" {
  direction = "ingress"
  ether_type = "IPv4"
  protocol = "tcp"
  port_range_min = 443
  port_range_max = 443
  remote_ip = "${ibm_compute_vm_instance.icp-proxy.0.private_subnet}"
  security_group_id = "${ibm_security_group.proxy_group.id}"
}

resource "ibm_security_group" "proxy_group" {
  name = "${var.deployment}-proxy-${random_id.clusterid.hex}"
  description = "allow incoming to proxy"
}

resource "ibm_security_group" "boot_node_public" {
  name = "${var.deployment}-boot-${random_id.clusterid.hex}"
  description = "allow incoming ssh"
}

# TODO restrict to allowed CIDR
resource "ibm_security_group_rule" "allow_ssh" {
  direction = "ingress"
  ether_type = "IPv4"
  protocol = "tcp"
  port_range_min = 22
  port_range_max = 22
  security_group_id = "${ibm_security_group.cluster_public.id}"
}
