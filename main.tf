###############################################################################
# Producer workspace: shared_vpc
#
# Mirrors the customer pattern -- one repo/workspace owns VPCs for every app,
# and exposes them as outputs for the app workspaces to read back.
#
# NOTE: there is deliberately no `backend` block here. Harness IaCM injects the
# state backend for the workspace running the code. Adding one would fight it.
###############################################################################

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "Region for the shared VPCs."
  type        = string
  default     = "us-east-1"
}

variable "apps" {
  description = "One VPC per entry. Key is the app name the consumer looks up."
  type        = map(string)

  default = {
    app_a = "10.10.0.0/16"
    app_b = "10.20.0.0/16"
  }
}

resource "aws_vpc" "app" {
  for_each = var.apps

  cidr_block           = each.value
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name      = "shared-${each.key}"
    ManagedBy = "harness-iacm"
    Workspace = "shared_vpc"
  }
}

###############################################################################
# Outputs -- this is the entire published contract. Everything else in this
# workspace's state is incidental, which is exactly the point of the FR:
# a consumer reading these via terraform_remote_state gets the whole state,
# not just this map.
###############################################################################

output "vpc_ids" {
  description = "App key -> VPC id."
  value       = { for k, v in aws_vpc.app : k => v.id }
}

output "vpc_cidrs" {
  description = "App key -> CIDR block."
  value       = { for k, v in aws_vpc.app : k => v.cidr_block }
}
