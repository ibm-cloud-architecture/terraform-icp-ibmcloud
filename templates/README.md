# Terraform ICP IBM Cloud

We have a collection of templates that can stand up a ICP environment in IBMCloud Infrastructure with minimal input.

## Selecting the right template

We currently have three templates available

- [icp-ce-minimal](icp-ce-minimal)
  * This template will deploy ICP Community Edition with a minimal amount of Virtual Machines and a minimal amount of services enabled
  *  Additional ICP services such as logging, monitoring and istio can be enabled as well as dedicated management nodes can be added with minor configuration changes
  * This template is suitable for a quick view of basic ICP and Kubernetes functionality, and simple PoCs and verifications

- [icp-ce-with-loadbalancers](icp-ce-with-loadbalancers)
  * Like the `icp-ce-minimal` template, this will deploy a minimal environment, but in this template Loadbalancers will also be created. This creates a topology more similar to the `icp-ee` environment, where external loadbalancers are a central part of the network design, but with less services and resources active
  *  This template is suitable for validation tests and PoCs where external loadbalancer functionality is required

- [icp-ee](icp-ee)
  * This template deploys a more robust environment, with control plane in a high availabilty configuration
  * By default a separate boot node is provisioned and all SSH communication goes through this
  * This configuration requires access to ICP Enterprise Edition, typically supplied as a tarball


Follow the link to these templates for more detailed information about them.
