
# Studio PUPSI - Secure Identity Perimeter Isolation
# Provider Setup (Fake/Local-Mocks for Validation)
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# 1. Isolated Virtual Private Cloud (VPC)
resource "aws_vpc" "perimeter" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "pupsi-identity-perimeter"
    Environment = "Production"
    Compliance  = "Strict-Zero-Trust"
  }
}

# 2. Strict Firewall Rules (Security Group)
resource "aws_security_group" "identity_anchor" {
  name        = "pupsi-secure-anchor-sg"
  description = "Strict stateful boundary isolation for identity verification layer"
  vpc_id      = aws_vpc.perimeter.id

  # Inbound: Only allow encrypted telemetry data from trusted hardware anchors
  ingress {
    description = "Allow TLS Telemetry from Hardware Anchors"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"] # Restricted internal segment
  }

  # Outbound: Deny everything by default (Zero-Trust egress topology)
  egress {
    description = "Deny all outbound traffic by default"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/32"] # Completely blocked
  }
}
