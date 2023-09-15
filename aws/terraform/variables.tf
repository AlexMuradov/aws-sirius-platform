variable region {
  type        = string
  description = "region"
}

variable "codepipeline_role_name" {
  description = "IAM Role name for CodePipeline"
  type        = string
  default     = "codepipeline_role"
}

variable "codepipeline_policy_name" {
  description = "IAM Policy name for CodePipeline"
  type        = string
  default     = "codepipeline_policy"
}

variable "codepipeline_name" {
  description = "Name for the CodePipeline"
  type        = string
  default     = "codepipeline"
}

variable "pipeline_log_role_name" {
  description = "IAM Role name for the pipeline logs"
  type        = string
  default     = "pipeline_log_role"
}

variable "pipeline_log_role_policy_name" {
  description = "IAM Role name for the policy pipeline logs"
  type        = string
  default     = "pipeline_log_role_policy"
}

variable "cloudwatch_log_group_name" {
  description = "CloudWatch Log Group name for CodePipeline"
  type        = string
  default     = "/aws/codepipeline/sirius"
}

variable "bucket_name" {
  description = "Name of the S3 bucket for storing model data"
  type        = string
  default     = "sirius-python-model-bucket"
}

variable "s3_object_key" {
  description = "S3 Object Key for the training data"
  type        = string
  default     = "train.json"
}

variable "cloudtrail_name" {
  description = "Name for the CloudTrail"
  type        = string
  default     = "codepipeline"
}

variable "cloudwatch_event_rule_name" {
  description = "Name for the CloudWatch Event Rule"
  type        = string
  default     = "codepipeline"
}

variable "cloudwatch_event_role_name" {
  description = "IAM Role name for CloudWatch Events"
  type        = string
  default     = "cloudwatch-event-codepipeline-role"
}
