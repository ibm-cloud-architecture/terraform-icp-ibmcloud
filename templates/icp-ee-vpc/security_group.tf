resource "ibm_is_security_group" "cluster_private" {
  name = "${var.deployment}-cluster-priv-${random_id.clusterid.hex}"
  vpc = "${ibm_is_vpc.icp_vpc.id}"
}

resource "ibm_is_security_group_rule" "cluster_ingress_from_self" {
  direction = "ingress"
  remote = "${ibm_is_security_group.cluster_private.id}"
  group = "${ibm_is_security_group.cluster_private.id}"
}

resource "ibm_is_security_group_rule" "cluster_ingress_master" {
  direction = "ingress"
  remote = "${ibm_is_security_group.master_node.id}"
  group = "${ibm_is_security_group.cluster_private.id}"
}

resource "ibm_is_security_group_rule" "cluster_ingress_ssh_boot" {
  direction = "ingress"
  remote = "${ibm_is_security_group.boot_node.id}"
  group = "${ibm_is_security_group.cluster_private.id}"
  tcp {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "cluster_egress_all" {
  direction = "egress"
  group = "${ibm_is_security_group.cluster_private.id}"
  remote = "0.0.0.0/0"
}

resource "ibm_is_security_group" "master_node" {
  name = "${var.deployment}-master-${random_id.clusterid.hex}"
  vpc = "${ibm_is_vpc.icp_vpc.id}"
}

resource "ibm_is_security_group_rule" "master_ingress_ssh_boot" {
  direction = "ingress"
  remote = "${ibm_is_security_group.boot_node.id}"
  group = "${ibm_is_security_group.master_node.id}"
  tcp {
    port_min = 22
    port_max = 22
  }
}

// TODO i am unsure about allowing all traffic to the master from the cluster, but it doesn't seem 
// work without it -- particularly in multi-tenant environments i'm uneasy about allowing 
// access to etcd, so NetworkPolicy should be used in the cluster to limit access to specific
// ports from specific pods (i.e. calico)
resource "ibm_is_security_group_rule" "master_ingress_all_cluster" {
  direction = "ingress"
  remote = "${ibm_is_security_group.cluster_private.id}"
  group = "${ibm_is_security_group.master_node.id}"
}


resource "ibm_is_security_group_rule" "master_egress_all" {
  direction = "egress"
  group = "${ibm_is_security_group.master_node.id}"
  remote = "0.0.0.0/0"
}


# restrict incoming on ports to LBaaS private subnet
resource "ibm_is_security_group_rule" "master_ingress_port_8443_all" {
  direction = "ingress"
  tcp {
    port_min = 8443
    port_max = 8443
  }
  group = "${ibm_is_security_group.master_node.id}"
  #remote = "${ibm_compute_vm_instance.icp-master.0.private_subnet}"
  # Sometimes LBaaS can be placed on a different subnet
  remote = "0.0.0.0/0"
}

# restrict to LBaaS private subnet
resource "ibm_is_security_group_rule" "master_ingress_port_8500_all" {
  direction = "ingress"
  tcp {
    port_min = 8500
    port_max = 8500
  }
  group = "${ibm_is_security_group.master_node.id}"
  # remote = "${ibm_compute_vm_instance.icp-master.0.private_subnet}"
  # Sometimes LBaaS can be placed on a different subnet
  remote = "0.0.0.0/0"
}

# restrict to LBaaS private subnet
resource "ibm_is_security_group_rule" "master_ingress_port_8600_all" {
  direction = "ingress"
  tcp {
    port_min = 8600
    port_max = 8600
  }
  group = "${ibm_is_security_group.master_node.id}"
  # remote = "${ibm_compute_vm_instance.icp-master.0.private_subnet}"
  # Sometimes LBaaS can be placed on a different subnet
  remote = "0.0.0.0/0"
}

# TODO restrict to LBaaS private subnet
resource "ibm_is_security_group_rule" "master_ingress_port_8001_all" {
  direction = "ingress"
  tcp {
    port_min = 8001
    port_max = 8001
  } 
  group = "${ibm_is_security_group.master_node.id}"
  # remote = "${ibm_compute_vm_instance.icp-master.0.private_subnet}"
  # Sometimes LBaaS can be placed on a different subnet
  remote = "0.0.0.0/0"
}


# TODO do we still need this rule?
resource "ibm_is_security_group_rule" "master_ingress_port_9443_all" {
  direction = "ingress"
  tcp {
    port_min = 9443
    port_max = 9443
  }
  group = "${ibm_is_security_group.master_node.id}"
  # remote = "${ibm_compute_vm_instance.icp-master.0.private_subnet}"
  # Sometimes LBaaS can be placed on a different subnet
  remote = "0.0.0.0/0"
}

# restrict to LBaaS private subnet
resource "ibm_is_security_group_rule" "proxy_ingress_port_80_all" {
  direction = "ingress"
  tcp {
    port_min = 80
    port_max = 80
  }
  group = "${ibm_is_security_group.proxy_node.id}"
  # Sometimes LBaaS can be placed on a different subnet
  remote = "0.0.0.0/0"
}

# restrict to LBaaS private subnet
resource "ibm_is_security_group_rule" "proxy_ingress_port_443_all" {
  direction = "ingress"
  tcp {
    port_min = 443
    port_max = 443
  }
  group = "${ibm_is_security_group.proxy_node.id}"
  # Sometimes LBaaS can be placed on a different subnet
  remote = "0.0.0.0/0"
}

resource "ibm_is_security_group" "proxy_node" {
  name = "${var.deployment}-proxy-${random_id.clusterid.hex}"
  vpc = "${ibm_is_vpc.icp_vpc.id}"
}

resource "ibm_is_security_group_network_interface_attachment" "proxy" {
  count = "${var.proxy["nodes"] > 0 ? var.proxy["nodes"] : var.master["nodes"]}"
  security_group    = "${ibm_is_security_group.proxy_node.id}"
  network_interface = "${var.proxy["nodes"] > 0 ? 
    element(ibm_is_instance.icp-proxy.*.primary_network_interface.0.id, count.index) :
    element(ibm_is_instance.icp-master.*.primary_network_interface.0.id, count.index)}"
}

resource "ibm_is_security_group" "boot_node" {
  name = "${var.deployment}-boot-${random_id.clusterid.hex}"
  vpc = "${ibm_is_vpc.icp_vpc.id}"
}

resource "ibm_is_security_group_network_interface_attachment" "boot" {
  security_group    = "${ibm_is_security_group.boot_node.id}"
  network_interface = "${ibm_is_instance.icp-boot.primary_network_interface.0.id}"
}

# TODO restrict to allowed CIDR
resource "ibm_is_security_group_rule" "boot_ingress_ssh_all" {
  group = "${ibm_is_security_group.boot_node.id}"
  direction = "ingress"
  remote = "0.0.0.0/0"
  tcp {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "boot_egress_all" {
  group = "${ibm_is_security_group.boot_node.id}"
  remote = "0.0.0.0/0"
  direction = "egress"
}
