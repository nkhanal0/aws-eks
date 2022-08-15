# Create a VPC

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "eks-vpc"
  }
}
# Create an Internet Gateway

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# Create 3 Private Subnets

resource "aws_subnet" "private_first" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "us-east-2a"

  tags = {
    "Name" = "EKS Private Subnet 1",
    "kubernetes.io/cluster/eks-cluster" = "shared"
  }
}
resource "aws_subnet" "private_second" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-2b"

  tags = {
    "Name" = "EKS Private Subnet 2",
    "kubernetes.io/cluster/eks-cluster" = "shared"
  }
}
resource "aws_subnet" "private_third" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-2c"

  tags = {
    "Name" = "EKS Private Subnet 3"
    "kubernetes.io/cluster/eks-cluster" = "shared"
  }
}


# Allocate 3 EIP to attach with NAT Gateways
resource "aws_eip" "nat_eip_1" {
  vpc        = true
  depends_on = [aws_internet_gateway.igw]
}
resource "aws_eip" "nat_eip_2" {
  vpc        = true
  depends_on = [aws_internet_gateway.igw]
}
resource "aws_eip" "nat_eip_3" {
  vpc        = true
  depends_on = [aws_internet_gateway.igw]
}

# Create 3 NAT Gateways to sit in each public subnet
resource "aws_nat_gateway" "nat_1" {
  allocation_id = aws_eip.nat_eip_1.id
  subnet_id     = aws_subnet.private_first.id
  depends_on    = [aws_internet_gateway.igw]
}
resource "aws_nat_gateway" "nat_2" {
  allocation_id = aws_eip.nat_eip_2.id
  subnet_id     = aws_subnet.private_second.id
  depends_on    = [aws_internet_gateway.igw]
}
resource "aws_nat_gateway" "nat_3" {
  allocation_id = aws_eip.nat_eip_3.id
  subnet_id     = aws_subnet.private_third.id
  depends_on    = [aws_internet_gateway.igw]
}

# Route Table for NAT
resource "aws_route_table" "nat_route_table_1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_1.id
  }
}
resource "aws_route_table" "nat_route_table_2" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_2.id
  }
}
resource "aws_route_table" "nat_route_table_3" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_3.id
  }
}

# Route Table Association for Private Subnet
resource "aws_route_table_association" "private_subnet_1" {
  subnet_id      = aws_subnet.private_first.id
  route_table_id = aws_route_table.nat_route_table_1.id
}
resource "aws_route_table_association" "private_subnet_2" {
  subnet_id      = aws_subnet.private_second.id
  route_table_id = aws_route_table.nat_route_table_2.id
}
resource "aws_route_table_association" "private_subnet_3" {
  subnet_id      = aws_subnet.private_third.id
  route_table_id = aws_route_table.nat_route_table_3.id
}

# EKS Cluster
resource "aws_eks_cluster" "example" {
  name     = "eks-cluster"
  role_arn = aws_iam_role.example.arn

  vpc_config {
    subnet_ids = [aws_subnet.private_first.id, aws_subnet.private_second.id, aws_subnet.private_third.id]
    security_group_ids = [aws_security_group.eks-cluster.id]
  }
  depends_on = [
    aws_iam_role_policy_attachment.example-AmazonEKSClusterPolicy,
  ]
}

output "endpoint" {
  value = aws_eks_cluster.example.endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.example.certificate_authority[0].data
}

resource "aws_iam_role" "example" {
  name = "eks-cluster-example"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.example.name
}

# Node Group
resource "aws_eks_node_group" "example" {
  cluster_name    = aws_eks_cluster.example.name
  node_group_name = "example"
  node_role_arn   = aws_iam_role.node_group_iam_role.arn
  subnet_ids = [aws_subnet.private_first.id, aws_subnet.private_second.id, aws_subnet.private_third.id]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
  tags = {
    "kubernetes.io/cluster/eks-cluster" = "shared"
  }

  depends_on = [
    aws_iam_role_policy_attachment.example-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.example-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.example-AmazonEC2ContainerRegistryReadOnly,
  ]
}
resource "aws_iam_role" "node_group_iam_role" {
  name = "eks-node-group-example"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group_iam_role.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group_iam_role.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group_iam_role.name
}

# Security Groups
resource "aws_security_group" "eks-cluster" {
  name        = "terraform-eks-cluster"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
