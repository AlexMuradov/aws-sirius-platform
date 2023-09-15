resource "aws_apigatewayv2_api" "http_api" {
  name          = var.api_name
  protocol_type = var.protocol_type
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = var.integration_type
  integration_uri  = var.lambda_invoke_arn
}

resource "aws_apigatewayv2_route" "http_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = var.route_key
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "http_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = var.stage_name
  description = var.stage_description
  auto_deploy = var.auto_deploy
}

resource "aws_lambda_permission" "api_gateway_permission" {
  action        = var.lambda_permission_action
  function_name = var.lambda_function_name
  principal     = var.lambda_permission_principal

  source_arn = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

output "http_api_url" {
  value = aws_apigatewayv2_api.http_api.api_endpoint
}
