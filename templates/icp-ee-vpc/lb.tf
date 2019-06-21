# because LBs in IBM Cloud cannot have parallel operations performed on them, we added
# depends_on blocks to try to restrict the number of parallel operations happening on a single
# LB at a time.  We attempt to build LB first, then pool (serially), then listener (serially), 
# then attach pool members (serially).
# the resources are listed in the order they should be created.

resource "ibm_is_lb" "proxy" {
  name = "${var.deployment}-proxy-${random_id.clusterid.hex}"
  subnets = ["${ibm_is_subnet.icp_subnet.*.id}"]
}

resource "ibm_is_lb_pool" "proxy-443" {
  lb = "${ibm_is_lb.proxy.id}"
  name = "${var.deployment}-proxy-443-${random_id.clusterid.hex}"
  protocol = "tcp"
  algorithm = "round_robin"
  health_delay = 60
  health_retries = 5
  health_timeout = 30
  health_type = "tcp"
}

resource "ibm_is_lb_listener" "proxy-443" {
  lb = "${ibm_is_lb.proxy.id}"
  protocol = "tcp"
  port = "443"
  default_pool = "${element(split("/",ibm_is_lb_pool.proxy-443.id),1)}"
}

resource "ibm_is_lb_pool_member" "proxy-443" {
  count = "${var.proxy["nodes"] > 0 ? var.proxy["nodes"] : var.master["nodes"]}"
  lb = "${ibm_is_lb.proxy.id}"
  pool = "${element(split("/",ibm_is_lb_pool.proxy-443.id),1)}"
  port = "443"
  target_address = "${var.proxy["nodes"] > 0 ?
    "${element(ibm_is_instance.icp-proxy.*.primary_network_interface.0.primary_ipv4_address, count.index)}" :
    "${element(ibm_is_instance.icp-master.*.primary_network_interface.0.primary_ipv4_address, count.index)}" }"
}

resource "ibm_is_lb_pool" "proxy-80" {
  lb = "${ibm_is_lb.proxy.id}"
  name = "${var.deployment}-proxy-80-${random_id.clusterid.hex}"
  protocol = "tcp"
  algorithm = "round_robin"
  health_delay = 60
  health_retries = 5
  health_timeout = 30
  health_type = "tcp"

  # ensure these are created serially -- LB limitations
  depends_on = [
    "ibm_is_lb_listener.proxy-443",
    //"ibm_is_lb_pool.proxy-443"
  ]
}

resource "ibm_is_lb_listener" "proxy-80" {
  lb = "${ibm_is_lb.proxy.id}"
  protocol = "tcp"
  port = "80"
  default_pool = "${element(split("/",ibm_is_lb_pool.proxy-80.id),1)}"

  # ensure these are created serially -- LB limitations
  depends_on = [
    "ibm_is_lb_listener.proxy-443",
    //"ibm_is_lb_pool.proxy-443"
  ]
}

resource "ibm_is_lb_pool_member" "proxy-80" {
  count = "${var.proxy["nodes"] > 0 ? var.proxy["nodes"] : var.master["nodes"]}"
  lb = "${ibm_is_lb.proxy.id}"
  pool = "${element(split("/",ibm_is_lb_pool.proxy-80.id),1)}"
  port = "80"
  target_address = "${var.proxy["nodes"] > 0 ?
    "${element(ibm_is_instance.icp-proxy.*.primary_network_interface.0.primary_ipv4_address, count.index)}" :
    "${element(ibm_is_instance.icp-master.*.primary_network_interface.0.primary_ipv4_address, count.index)}" }"

  # ensure these are created serially -- LB limitations
  depends_on = [
    "ibm_is_lb_pool_member.proxy-443",
    //"ibm_is_lb_pool.proxy-443",
    //"ibm_is_lb_listener.proxy-443"
  ]
}

resource "ibm_is_lb" "master" {
  name = "${var.deployment}-mastr-${random_id.clusterid.hex}"
  subnets = ["${ibm_is_subnet.icp_subnet.*.id}"]
}

resource "ibm_is_lb_pool" "master-8001" {
  lb = "${ibm_is_lb.master.id}"
  name = "${var.deployment}-master-8001-${random_id.clusterid.hex}"
  protocol = "tcp"
  algorithm = "round_robin"
  health_delay = 60
  health_retries = 5
  health_timeout = 30
  health_type = "tcp"
}

resource "ibm_is_lb_listener" "master-8001" {
  protocol = "tcp"
  lb = "${ibm_is_lb.master.id}"
  port = "8001"
  default_pool = "${element(split("/",ibm_is_lb_pool.master-8001.id),1)}"
}

resource "ibm_is_lb_pool_member" "master-8001" {
  count = "${var.master["nodes"]}"
  lb = "${ibm_is_lb.master.id}"
  pool = "${element(split("/",ibm_is_lb_pool.master-8001.id),1)}"
  port = "8001"
  target_address = "${element(ibm_is_instance.icp-master.*.primary_network_interface.0.primary_ipv4_address, count.index)}"
}

resource "ibm_is_lb_pool" "master-8443" {
  lb = "${ibm_is_lb.master.id}"
  name = "${var.deployment}-master-8443-${random_id.clusterid.hex}"
  protocol = "tcp"
  algorithm = "round_robin"
  health_delay = 60
  health_retries = 5
  health_timeout = 30
  health_type = "tcp"

/*
  # ensure these are created serially -- LB limitations
  depends_on = [
    "ibm_is_lb_listener.master-8001",
    //"ibm_is_lb_pool.master-8001"
  ]
  */
}

resource "ibm_is_lb_listener" "master-8443" {
  protocol = "tcp"
  lb = "${ibm_is_lb.master.id}"
  port = "8443"
  default_pool = "${element(split("/",ibm_is_lb_pool.master-8443.id),1)}"

  # ensure these are created serially -- LB limitations
  depends_on = [
    "ibm_is_lb_listener.master-8001",
    //"ibm_is_lb_pool.master-8001"
  ]

}

resource "ibm_is_lb_pool_member" "master-8443" {
  count = "${var.master["nodes"]}"
  lb = "${ibm_is_lb.master.id}"
  pool = "${element(split("/",ibm_is_lb_pool.master-8443.id),1)}"
  port = "8443"
  target_address = "${element(ibm_is_instance.icp-master.*.primary_network_interface.0.primary_ipv4_address, count.index)}"

  # ensure these are created serially -- LB limitations
  depends_on = [
    "ibm_is_lb_pool_member.master-8001"
  ]

}

resource "ibm_is_lb_pool" "master-8500" {
  lb = "${ibm_is_lb.master.id}"
  name = "${var.deployment}-master-8500-${random_id.clusterid.hex}"
  protocol = "tcp"
  algorithm = "round_robin"
  health_delay = 60
  health_retries = 5
  health_timeout = 30
  health_type = "tcp"

  # ensure these are created serially -- LB limitations
  /*
  depends_on = [
    "ibm_is_lb_listener.master-8443",
    //"ibm_is_lb_pool.master-8443",
    "ibm_is_lb_listener.master-8001",
    //"ibm_is_lb_pool.master-8001"
  ]
  */

}

resource "ibm_is_lb_listener" "master-8500" {
  protocol = "tcp"
  lb = "${ibm_is_lb.master.id}"
  port = "8500"
  default_pool = "${element(split("/",ibm_is_lb_pool.master-8500.id),1)}"

  # ensure these are created serially -- LB limitations
  depends_on = [
    "ibm_is_lb_listener.master-8443",
    //"ibm_is_lb_pool.master-8443",
    "ibm_is_lb_listener.master-8001",
    //"ibm_is_lb_pool.master-8001"
  ]


}

resource "ibm_is_lb_pool_member" "master-8500" {
  count = "${var.master["nodes"]}"
  lb = "${ibm_is_lb.master.id}"
  pool = "${element(split("/",ibm_is_lb_pool.master-8500.id),1)}"
  port = "8500"
  target_address = "${element(ibm_is_instance.icp-master.*.primary_network_interface.0.primary_ipv4_address, count.index)}"

  # ensure these are created serially -- LB limitations
  depends_on = [
    "ibm_is_lb_pool_member.master-8001",
    "ibm_is_lb_pool_member.master-8443"
  ]

}

resource "ibm_is_lb_pool" "master-8600" {
  lb = "${ibm_is_lb.master.id}"
  name = "${var.deployment}-master-8600-${random_id.clusterid.hex}"
  protocol = "tcp"
  algorithm = "round_robin"
  health_delay = 60
  health_retries = 5
  health_timeout = 30
  health_type = "tcp"

  # ensure these are created serially -- LB limitations
  /*
  depends_on = [
    "ibm_is_lb_listener.master-8500",
    //"ibm_is_lb_pool.master-8500",
    "ibm_is_lb_listener.master-8443",
    //"ibm_is_lb_pool.master-8443",
    "ibm_is_lb_listener.master-8001",
    //"ibm_is_lb_pool.master-8001"
  ]
  */

}

resource "ibm_is_lb_listener" "master-8600" {
  protocol = "tcp"
  lb = "${ibm_is_lb.master.id}"
  port = "8600"
  default_pool = "${element(split("/",ibm_is_lb_pool.master-8600.id),1)}"

  # ensure these are created serially -- LB limitations
  depends_on = [
    "ibm_is_lb_listener.master-8500",
    //"ibm_is_lb_pool.master-8500",
    "ibm_is_lb_listener.master-8443",
    //"ibm_is_lb_pool.master-8443",
    "ibm_is_lb_listener.master-8001",
    //"ibm_is_lb_pool.master-8001"
  ]

}

resource "ibm_is_lb_pool_member" "master-8600" {
  count = "${var.master["nodes"]}"
  lb = "${ibm_is_lb.master.id}"
  pool = "${element(split("/",ibm_is_lb_pool.master-8600.id),1)}"
  port = "8600"
  target_address = "${element(ibm_is_instance.icp-master.*.primary_network_interface.0.primary_ipv4_address, count.index)}"

  depends_on = [
    "ibm_is_lb_pool_member.master-8001",
    "ibm_is_lb_pool_member.master-8443",
    "ibm_is_lb_pool_member.master-8500"
  ]

}

resource "ibm_is_lb_pool" "master-9443" {
  lb = "${ibm_is_lb.master.id}"
  name = "${var.deployment}-master-9443-${random_id.clusterid.hex}"
  protocol = "tcp"
  algorithm = "round_robin"
  health_delay = 60
  health_retries = 5
  health_timeout = 30
  health_type = "tcp"

  /*
  # ensure these are created serially -- LB limitations
  depends_on = [
    "ibm_is_lb_listener.master-8600",
    //"ibm_is_lb_pool.master-8600",
    "ibm_is_lb_listener.master-8500",
    //"ibm_is_lb_pool.master-8500",
    "ibm_is_lb_listener.master-8443",
    //"ibm_is_lb_pool.master-8443",
    "ibm_is_lb_listener.master-8001",
    //"ibm_is_lb_pool.master-8001"
  ]
  */

}

resource "ibm_is_lb_listener" "master-9443" {
  protocol = "tcp"
  lb = "${ibm_is_lb.master.id}"
  port = "9443"
  default_pool = "${element(split("/",ibm_is_lb_pool.master-9443.id),1)}"

  # ensure these are created serially -- LB limitations
  depends_on = [
    "ibm_is_lb_listener.master-8600",
    //"ibm_is_lb_pool.master-8600",
    "ibm_is_lb_listener.master-8500",
    //"ibm_is_lb_pool.master-8500",
    "ibm_is_lb_listener.master-8443",
    //"ibm_is_lb_pool.master-8443",
    "ibm_is_lb_listener.master-8001",
    //"ibm_is_lb_pool.master-8001"
  ]
}

resource "ibm_is_lb_pool_member" "master-9443" {
  count = "${var.master["nodes"]}"
  lb = "${ibm_is_lb.master.id}"
  pool = "${element(split("/",ibm_is_lb_pool.master-9443.id),1)}"
  port = "9443"
  target_address = "${element(ibm_is_instance.icp-master.*.primary_network_interface.0.primary_ipv4_address, count.index)}"

  depends_on = [
    "ibm_is_lb_pool_member.master-8001",
    "ibm_is_lb_pool_member.master-8443",
    "ibm_is_lb_pool_member.master-8500",
    "ibm_is_lb_pool_member.master-8600"
  ]

}


