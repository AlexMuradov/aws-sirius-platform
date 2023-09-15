# api_gateway_module/variables.tf

variable "api_name" {
  description = "Name of the API"
  type        = string
}

variable "protocol_type" {
  description = "Protocol type of the API"
  type        = string
  default     = "HTTP"
}

variable "integration_type" {
  description = "Type of the integration for the API"
  type        = string
  default     = "AWS_PROXY"
}

variable "lambda_invoke_arn" {
  description = "ARN used to invoke the Lambda function"
  type        = string
}

variable "route_key" {
  description = "Route key for the API Gateway route"
  type        = string
  default     = "ANY /"
}

variable "stage_name" {
  description = "Name of the stage for the API Gateway"
  type        = string
  default     = "v1"
}

variable "stage_description" {
  description = "Description of the stage for the API Gateway"
  type        = string
  default     = "Version 1 of the API"
}

variable "auto_deploy" {
  description = "Whether to automatically deploy the API Gateway stage"
  type        = bool
  default     = true
}

variable "lambda_permission_action" {
  description = "Action for the Lambda permission"
  type        = string
  default     = "lambda:InvokeFunction"
}

variable "lambda_function_name" {
  description = "Name of the Lambda function to be called by the API Gateway"
  type        = string
}

variable "lambda_permission_principal" {
  description = "Principal for the Lambda permission"
  type        = string
  default     = "apigateway.amazonaws.com"
}
