resource "aws_vpc" "management_vpc" {
  cidr_block = var.management_vpc_cidr
  tags = merge(var.tags, { Name = var.management_vpc_name })
}

resource "aws_subnet" "management_subnet" {
  vpc_id = aws_vpc.management_vpc.id
  cidr_block = var.management_vpc_cidr
  tags = merge(var.tags, { Name = var.management_subnet_name })
}

data "aws_subnet" "k8s_subnet" {
  for_each = toset(var.k8s_subnet_ids)
  id = each.key
}

data "aws_vpc" "k8s_vpc" {
  for_each = { for subnet in data.aws_subnet.k8s_subnet: subnet.vpc_id => subnet... }
  id = each.key
}

resource "aws_vpc_peering_connection" "management_vpc_peering" {
  for_each = data.aws_vpc.k8s_vpc
  peer_vpc_id = each.key
  vpc_id = aws_vpc.management_vpc.id
  auto_accept = true
  tags = merge(var.tags, { Name = "${var.management_vpc_name}-${each.value.tags["Name"]}" })
}

data "aws_route_table" "k8s_subnet_route_table" {
  for_each = data.aws_subnet.k8s_subnet
  subnet_id = each.value.id
}

resource "aws_route_table" "management_route_table" {
  vpc_id = aws_vpc.management_vpc.id
  dynamic "route" {
    for_each = data.aws_route_table.k8s_subnet_route_table
    content {
      cidr_block = data.aws_subnet.k8s_subnet[route.value.subnet_id].cidr_block
      vpc_peering_connection_id = aws_vpc_peering_connection.management_vpc_peering[route.value.vpc_id].id
    }
  }
  tags = merge(var.tags, { Name = "${var.management_vpc_name}-route-table" })
}

resource "aws_route" "k8s_subnet_route" {
  for_each = { for route_table in data.aws_route_table.k8s_subnet_route_table: route_table.route_table_id => route_table.vpc_id... }
  route_table_id = each.key
  destination_cidr_block = var.management_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.management_vpc_peering[each.value[0]].id
}

data "aws_security_group" "k8s_security_group" {
  for_each = toset(var.k8s_security_group_ids)
  id = each.key
}

resource "aws_security_group" "management_security_group" {
  name = "xosphere-management-security-group"
  vpc_id = aws_vpc.management_vpc.id
  dynamic "ingress" {
    for_each = data.aws_subnet.k8s_subnet
    content {
      cidr_blocks = [ingress.value.cidr_block]
      from_port = 0
      to_port = 0
      protocol = "-1"
    }
  }
  dynamic "egress" {
    for_each = data.aws_subnet.k8s_subnet
    content {
      cidr_blocks = [egress.value.cidr_block]
      from_port = 0
      to_port = 0
      protocol = "-1"
    }
  }
  tags = merge(var.tags, { Name = "xosphere-management-security-group" })
}

resource "aws_security_group_rule" "k8s_security_group_ingress_rule" {
  for_each = toset(var.k8s_security_group_ids)
  security_group_id = each.key
  type = "ingress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = [aws_subnet.management_subnet.cidr_block]
}

resource "aws_security_group_rule" "k8s_security_group_egress_rule" {
  for_each = toset(var.k8s_security_group_ids)
  security_group_id = each.key
  type = "egress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = [aws_subnet.management_subnet.cidr_block]
}

output "management_subnet_id" {
  value = aws_subnet.management_subnet.id
  description = "Subnet id for the newly created management VPC. This id should be used as the value for the k8s_subnet_ids for the Instance Orchestrator module."
}

output "management_security_group_id" {
  value = aws_security_group.management_security_group.id
  description = "Security Group id for the newly created management VPC. This id should be used as the value for the k8s_security_group_ids for the Instance Orchestrator module."
}