
# ==========================================================================================================
# ⚡ Studio PUPSI: Next-Gen Enterprise Security & S/4HANA Cloud Integration Perimeter
# 
# Module: Secure S/4HANA to AWS & SAP BTP Hyperscaler Bridge
# Focus: Deterministic Access, Private Networking & Clean Core Architecture
# ==========================================================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    sapbtp = {
      source  = "SAP/sapbtp"
      version = "~> 1.0"
    }
  }
}

# ----------------------------------------------------------------------------------------------------------
# 1. NETWORKING PERIMETER: Dedicated VPC for SAP Integration
# ----------------------------------------------------------------------------------------------------------
resource "aws_vpc" "sap_integration_vpc" {
  cidr_block           = "10.240.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "pupsi-s4-integration-vpc"
    Environment = "Production"
    Compliance  = "SOX-SAP-Strict"
  }
}

# 2. PRIVATE SUBNET: Isolated Layer for SAP Cloud Connector & Integration Runtime
resource "aws_subnet" "sap_private_subnet" {
  vpc_id            = aws_vpc.sap_integration_vpc.id
  cidr_block        = "10.240.10.0/24"
  availability_zone = "eu-central-1a" # Frankfurt (Low Latency to SAP Core)

  tags = {
    Name = "pupsi-sap-private-subnet"
  }
}

# ----------------------------------------------------------------------------------------------------------
# 2. SECURITY GROUP: Strict Inbound Control for S/4HANA OData / RFC Traffic
# ----------------------------------------------------------------------------------------------------------
resource "aws_security_group" "sap_bridge_sg" {
  name        = "pupsi-sap-bridge-sg"
  description = "Enforce deterministic isolation for S4HANA Cloud Connector"
  vpc_id      = aws_vpc.sap_integration_vpc.id

  # Inbound: Allow HTTPS only from trusted internal Corporate Network (S/4HANA Source)
  ingress {
    description = "S4HANA Core HTTPS Inbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.100.0.0/16"] # Your On-Premises / Private Cloud S/4HANA Range
  }

  # Outbound: Restrict traffic exclusively to SAP BTP / Hyperscaler endpoints
  egress {
    description = "Secure Outbound to SAP BTP/AWS Endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Narrow down to BTP IP Ranges in production
  }

  tags = {
    Name = "pupsi-sap-bridge-security-enforcement"
  }
}

# ----------------------------------------------------------------------------------------------------------
# 3. SAP BTP PROVISIONING: "Keep the Core Clean" Extension Layer
# ----------------------------------------------------------------------------------------------------------

# Create an isolated Subaccount on SAP BTP for S/4HANA Extensions
resource "sapbtp_subaccount" "s4_extension_subaccount" {
  name        = "S4HANA-CleanCore-Extensions-Prod"
  subdomain   = "pupsi-s4-extensions-prod"
  region      = "cf-eu10" # SAP BTP running on AWS Frankfurt Infrastructure
  legal_entity = "Studio PUPSI Enterprise"
}

# Provision Kyma (SAP's Managed Kubernetes Engine) for microservice extensions
resource "sapbtp_subaccount_environment_instance" "kyma_runtime" {
  subaccount_id    = sapbtp_subaccount.s4_extension_subaccount.id
  name             = "pupsi-s4-kyma-cluster"
  environment_type = "kyma"
  service_name     = "kymaruntime"
  plan_name        = "aws" # Explicitly bound to AWS underlying hardware
}

# ----------------------------------------------------------------------------------------------------------
# 4. SAP CONNECTIVITY: Define Destination to S/4HANA System
# ----------------------------------------------------------------------------------------------------------
resource "sapbtp_subaccount_destination" "s4hana_rfc_destination" {
  subaccount_id = sapbtp_subaccount.s4_extension_subaccount.id
  name          = "S4HANA_ERP_CORE"
  type          = "HTTP"
  url           = "https://pupsi-enterprise.com"
  authentication_type = "PrincipalPropagation" # Secure Identity Forwarding
  proxy_type          = "OnPremise"            # Routes traffic via SAP Cloud Connector
  
  description = "Deterministic connection to S4HANA ERP Core System"
}
