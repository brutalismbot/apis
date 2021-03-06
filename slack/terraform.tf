###############
#   LOCALS    #
###############

locals {
  routes = [
    "GET /health",
    "GET /install",
    "GET /oauth/v2",
    "HEAD /health",
    "HEAD /install",
    "POST /events",
    "POST /health",
  ]
}

################
#   HTTP API   #
################

resource "aws_apigatewayv2_api" "http_api" {
  description   = "Brutalismbot Slack API"
  name          = "brutalismbot/slack"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  auto_deploy = true
  description = "Brutalismbot Slack API default stage"
  name        = "$default"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.http_api.arn

    format = jsonencode({
      httpMethod     = "$context.httpMethod"
      ip             = "$context.identity.sourceIp"
      protocol       = "$context.protocol"
      requestId      = "$context.requestId"
      requestTime    = "$context.requestTime"
      responseLength = "$context.responseLength"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
    })
  }

  lifecycle { ignore_changes = [deployment_id] }
}

resource "aws_apigatewayv2_api_mapping" "mapping" {
  api_mapping_key = "slack"
  api_id          = aws_apigatewayv2_api.http_api.id
  domain_name     = "api.brutalismbot.com"
  stage           = aws_apigatewayv2_stage.default.id
}

########################
#   HTTP API :: LOGS   #
########################

resource "aws_cloudwatch_log_group" "http_api" {
  name              = "/aws/apigatewayv2/${aws_apigatewayv2_api.http_api.name}"
  retention_in_days = 14
}

################################
#   HTTP API :: INTEGRATIONS   #
################################

data "terraform_remote_state" "functions" {
  backend = "remote"

  config = {
    organization = "brutalismbot"

    workspaces = { name = "functions" }
  }
}

data "aws_lambda_function" "proxy" {
  function_name = data.terraform_remote_state.functions.outputs.functions.api_slack.function_name
}

resource "aws_apigatewayv2_integration" "proxy" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  connection_type        = "INTERNET"
  description            = "Brutalismbot Slack API Lambda proxy"
  integration_method     = "POST"
  integration_type       = "AWS_PROXY"
  integration_uri        = data.aws_lambda_function.proxy.arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 3000
}

resource "aws_lambda_permission" "permissions" {
  count         = length(local.routes)
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.proxy.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/${aws_apigatewayv2_stage.default.name}/${replace(element(local.routes, count.index), " ", "")}"
}

##########################
#   HTTP API :: ROUTES   #
##########################

resource "aws_apigatewayv2_route" "routes" {
  count              = length(local.routes)
  api_id             = aws_apigatewayv2_api.http_api.id
  route_key          = element(local.routes, count.index)
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.proxy.id}"
}
