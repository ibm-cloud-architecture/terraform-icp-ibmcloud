data "ibm_is_region" "icp_region" {
  name = "${var.vpc_region}"
}

data "ibm_is_zone" "icp_zone" {
  count  = "${length(var.vpc_subnet_cidr)}"
  region = "${data.ibm_is_region.icp_region.name}"
  name 	 = "${format("%s-%d", data.ibm_is_region.icp_region.name, count.index + 1)}"
}


resource "ibm_is_vpc" "icp_vpc" {
  name = "${var.deployment}-${random_id.clusterid.hex}"
}

resource "ibm_is_vpc_address_prefix" "icp_vpc_address_prefix" {
  count           = "${length(var.vpc_address_prefix)}"
  name 	          = "${format("%s-addr-%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"
  vpc             = "${ibm_is_vpc.icp_vpc.id}"
  zone 	          = "${element(data.ibm_is_zone.icp_zone.*.name, count.index)}"
  cidr            = "${element(var.vpc_address_prefix, count.index)}"
}

resource "ibm_is_subnet" "icp_subnet" {
  depends_on = [ 
    "ibm_is_vpc_address_prefix.icp_vpc_address_prefix"
  ]

  count           = "${length(var.vpc_subnet_cidr)}"
  name 	          = "${format("%s-subnet-%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"
  vpc             = "${ibm_is_vpc.icp_vpc.id}"
  zone 	          = "${element(data.ibm_is_zone.icp_zone.*.name, count.index)}"
  ipv4_cidr_block = "${element(var.vpc_subnet_cidr, count.index)}"
  public_gateway  = "${element(ibm_is_public_gateway.pub_gateway.*.id, count.index)}"
}

resource "ibm_is_public_gateway" "pub_gateway" {
  count           = "${length(var.vpc_subnet_cidr)}"
  vpc             = "${ibm_is_vpc.icp_vpc.id}"
  zone 	          = "${element(data.ibm_is_zone.icp_zone.*.name, count.index)}"
  name 	          = "${format("%s-pgw-%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"
}