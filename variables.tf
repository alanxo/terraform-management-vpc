variable "k8s_security_group_ids" {
  description = "The security group ids for all Kubernetes clusters"
  type = list(string)
}

variable "k8s_subnet_ids" {
  description = "The subnet ids for all Kubernetes subnets"
  type = list(string)
}

variable "management_vpc_cidr" {
  description = "The IPv4 CIDR block to use for the management VPC (e.g. 10.0.0.0/24)"
  type = string
}

variable "management_vpc_name" {
  description = "The Name tag to use for the management VPC"
  type = string
  default = "xosphere-management-vpc"
}

variable "management_subnet_name" {
  description = "The Name tag to use for the management subnet"
  type = string
  default = "xosphere-management-subnet"
}

variable "tags" {
  description = "Map of tag keys and values to be applied to objects created by this module (where applicable)"
  type = map(string)
  default = {}
}