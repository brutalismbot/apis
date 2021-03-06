#################
#   TERRAFORM   #
#################

terraform {
  required_version = "~> 1.0"

  cloud {
    organization = "brutalismbot"

    workspaces { name = "api" }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

#################
#   VARIABLES   #
#################

variable "AWS_ROLE_ARN" {}

##############
#   LOCALS   #
##############

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  s3_bucket_name            = "brutalismbot-${local.region}-website"
  s3_bucket_object_arn_glob = "arn:aws:s3:::${local.s3_bucket_name}/*"

  tags = {
    App  = "Brutalismbot"
    Name = "Brutalismbot"
    Repo = "https://github.com/brutalismbot/apis"
  }
}

###########
#   AWS   #
###########

provider "aws" {
  region = "us-west-2"
  assume_role { role_arn = var.AWS_ROLE_ARN }
  default_tags { tags = local.tags }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

###########
#   ACM   #
###########

data "aws_acm_certificate" "us_west_2" {
  domain   = "brutalismbot.com"
  statuses = ["ISSUED"]
}

###################
#   API GATEWAY   #
###################

resource "aws_apigatewayv2_domain_name" "us_west_2" {
  domain_name = "api.brutalismbot.com"

  domain_name_configuration {
    certificate_arn = data.aws_acm_certificate.us_west_2.arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

#######################
#   ROUTE53 :: ZONE   #
#######################

data "aws_route53_zone" "zone" {
  name = "brutalismbot.com."
}

##########################
#   ROUTE53 :: RECORDS   #
##########################

resource "aws_route53_record" "us_west_2_a" {
  # health_check_id = aws_route53_health_check.healthcheck.id
  name           = aws_apigatewayv2_domain_name.us_west_2.domain_name
  set_identifier = "us-west-2.${aws_apigatewayv2_domain_name.us_west_2.domain_name}"
  type           = "A"
  zone_id        = data.aws_route53_zone.zone.id

  alias {
    evaluate_target_health = true
    name                   = aws_apigatewayv2_domain_name.us_west_2.domain_name_configuration.0.target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.us_west_2.domain_name_configuration.0.hosted_zone_id
  }

  latency_routing_policy { region = "us-west-2" }
}

###############################
#   ROUTE53 :: HEALTHCHECKS   #
###############################

/*
resource "aws_route53_health_check" "healthcheck" {
  failure_threshold = "3"
  fqdn              = "api.brutalismbot.com"
  measure_latency   = true
  port              = 443
  request_interval  = "30"
  resource_path     = "/slack/health"
  type              = "HTTPS"
}
*/

###############
#   MODULES   #
###############

module "slack" { source = "./slack" }
module "slack_beta" { source = "./slack/beta" }

###############
#   OUTPUTS   #
###############

output "aws_apigatewayv2_domain_name" { value = aws_apigatewayv2_domain_name.us_west_2.domain_name }
