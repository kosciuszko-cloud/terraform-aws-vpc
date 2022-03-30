resource "aws_vpc" "vpc" {
  enable_dns_hostnames = true
  cidr_block           = format(
    "10.%s.0.0/16",
    var.octet2,
  )

  tags = {
    Name = "${var.env}_vpc"
  }
}

resource "aws_subnet" "public" {
  count = length(var.azs)

  vpc_id            = aws_vpc.vpc.id
  cidr_block        = format(
    "10.%s.%s.0/24",
    var.octet2,
    count.index,
  )
  availability_zone = "${var.region}${var.azs[count.index]}"

  tags = {
    "Name" = format(
      "%s_public_%s_sn",
      var.env,
      var.azs[count.index],
    )
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.env}_igw"
  }
}

resource "aws_eip" "nat_eip" {
  count = length(var.azs)

  vpc = true
}

resource "aws_nat_gateway" "nat" {
  count = length(var.azs)

  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    "Name" = format(
      "%s_%s_nat",
      var.env,
      var.azs[count.index],
    )
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.env}_public_rt"
  }
}

resource "aws_route" "public_rt_igw_r" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_rta" {
  count = length(var.azs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_network_acl" "public_nacl" {
  vpc_id     = aws_vpc.vpc.id
  subnet_ids = aws_subnet.public.*.id

  egress = [
    {
      protocol   = "6"
      rule_no    = 100
      action     = "allow"
      cidr_block = "0.0.0.0/0"
      from_port  = 80
      to_port    = 80
      icmp_code  = 0
      icmp_type  = 0
      ipv6_cidr_block = null
    },
    {
      protocol   = "6"
      rule_no    = 101
      action     = "allow"
      cidr_block = "0.0.0.0/0"
      from_port  = 443
      to_port    = 443
      icmp_code  = 0
      icmp_type  = 0
      ipv6_cidr_block = null
    },
    {
      protocol   = "6"
      rule_no    = 200
      action     = "allow"
      cidr_block = "0.0.0.0/0"
      from_port  = 1024
      to_port    = 65535
      icmp_code  = 0
      icmp_type  = 0
      ipv6_cidr_block = null
    }
  ]

  ingress = [
    {
      protocol   = "6"
      rule_no    = 100
      action     = "allow"
      cidr_block = "0.0.0.0/0"
      from_port  = 80
      to_port    = 80
      icmp_code  = 0
      icmp_type  = 0
      ipv6_cidr_block = null
    },
    {
      protocol   = "6"
      rule_no    = 101
      action     = "allow"
      cidr_block = "0.0.0.0/0"
      from_port  = 443
      to_port    = 443
      icmp_code  = 0
      icmp_type  = 0
      ipv6_cidr_block = null
    },
    {
      protocol   = "6"
      rule_no    = 200
      action     = "allow"
      cidr_block = "0.0.0.0/0"
      from_port  = 1024
      to_port    = 65535
      icmp_code  = 0
      icmp_type  = 0
      ipv6_cidr_block = null
    }
  ]

  tags = {
    Name = "${var.env}_public_nacl"
  }
}

resource "aws_subnet" "private" {
  count = length(var.private_sn) * length(var.azs)

  vpc_id            = aws_vpc.vpc.id
  cidr_block        = format(
    "10.%s.%s.0/24",
    var.octet2,
    (floor(count.index / length(var.azs)) + 1) * 10  + count.index % length(var.azs),
  )
  availability_zone = format(
    "%s%s",
    var.region,
    var.azs[count.index % length(var.azs)],
  )

  tags = {
    "Name" = format(
      "%s_%s_%s_sn",
      var.env,
      var.private_sn[floor(count.index / length(var.azs))],
      var.azs[count.index % length(var.azs)],
    )
  }
}

resource "aws_route_table" "private_rt" {
  count = length(var.azs)

  vpc_id = aws_vpc.vpc.id

  tags = {
    "Name" = format(
      "%s_private_%s_rt",
      var.env,
      var.azs[count.index],
    )
  }
}

resource "aws_route" "private_rt_nat_r" {
  count = length(var.azs)

  route_table_id         = aws_route_table.private_rt[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[count.index].id
}

resource "aws_route_table_association" "private_rta" {
  count = length(var.private_sn) * length(var.azs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private_rt[count.index % length(var.azs)].id
}

resource "aws_network_acl" "private_nacl" {
  vpc_id     = aws_vpc.vpc.id
  subnet_ids = aws_subnet.private.*.id

  egress = [
    {
      protocol   = "6"
      rule_no    = 100
      action     = "allow"
      cidr_block = "0.0.0.0/0"
      from_port  = 80
      to_port    = 80
      icmp_code  = 0
      icmp_type  = 0
      ipv6_cidr_block = null
    },
    {
      protocol   = "6"
      rule_no    = 101
      action     = "allow"
      cidr_block = "0.0.0.0/0"
      from_port  = 443
      to_port    = 443
      icmp_code  = 0
      icmp_type  = 0
      ipv6_cidr_block = null
    },
    {
      protocol   = "6"
      rule_no    = 200
      action     = "allow"
      cidr_block = format(
        "10.%s.0.0/16",
        var.octet2,
      )
      from_port  = 1024
      to_port    = 65535
      icmp_code  = 0
      icmp_type  = 0
      ipv6_cidr_block = null
    }
  ]

  ingress = [
    {
      protocol   = "6"
      rule_no    = 100
      action     = "allow"
      cidr_block = format(
        "10.%s.0.0/16",
        var.octet2,
      )
      from_port  = 80
      to_port    = 80
      icmp_code  = 0
      icmp_type  = 0
      ipv6_cidr_block = null
    },
    {
      protocol   = "6"
      rule_no    = 101
      action     = "allow"
      cidr_block = format(
        "10.%s.0.0/16",
        var.octet2,
      )
      from_port  = 443
      to_port    = 443
      icmp_code  = 0
      icmp_type  = 0
      ipv6_cidr_block = null
    },
    {
      protocol   = "6"
      rule_no    = 200
      action     = "allow"
      cidr_block = "0.0.0.0/0"
      from_port  = 1024
      to_port    = 65535
      icmp_code  = 0
      icmp_type  = 0
      ipv6_cidr_block = null
    }
  ]

  tags = {
    Name = "${var.env}_private_nacl"
  }
}

resource "aws_security_group" "external_sg" {
  name        = "${var.env}_external_sg"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "${var.env}_external_sg"
  }
}

resource "aws_security_group_rule" "external_sg_ingress" {
  security_group_id = aws_security_group.external_sg.id
  type              = "ingress"
  from_port         = 80
  to_port           = 443
  protocol          = 6
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "external_sg_egress" {
  security_group_id = aws_security_group.external_sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = -1
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group" "internal_sg" {
  name        = "${var.env}_internal_sg"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "${var.env}_internal_sg"
  }
}

resource "aws_security_group_rule" "internal_sg_ingress" {
  security_group_id = aws_security_group.internal_sg.id
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = -1
  source_security_group_id = aws_security_group.internal_sg.id
}

resource "aws_security_group_rule" "internal_sg_egress" {
  security_group_id = aws_security_group.internal_sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = -1
  cidr_blocks       = ["0.0.0.0/0"]
}

output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "external_sg_id" {
  value = aws_security_group.external_sg.id
}

output "internal_sg_id" {
  value = aws_security_group.internal_sg.id
}
