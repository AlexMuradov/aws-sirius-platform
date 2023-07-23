locals {
    region = var.region
    s3_bucket_name = "sirius-python-model-bucket"
    code_commit_repository_name = "python-model-repository"
    code_commit_description = "Repository for Python model code"
    code_build_project_name = "python-model-build"
    code_build_description = "Build project for training Python model"
    code_build_timeout = "30"
}

resource "aws_codecommit_repository" "python_model_repository" {
  repository_name = local.code_commit_repository_name
  description     = local.code_commit_description
}

data "aws_codecommit_repository" "python_model_repository" {
  repository_name = local.code_commit_repository_name
  depends_on = [
    aws_codecommit_repository.python_model_repository
  ]
}

output "codecommit_repo_url" {
  value = data.aws_codecommit_repository.python_model_repository.clone_url_http
}

resource "aws_s3_bucket" "model_data_bucket" {
  bucket = local.s3_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "versioning_example" {
  bucket = aws_s3_bucket.model_data_bucket.id
  versioning_configuration {
    status = "Disabled"
  }
  depends_on = [
    aws_s3_bucket.model_data_bucket
  ]
}

resource "aws_codebuild_project" "python_model_build" {
  name          = local.code_build_project_name
  description   = local.code_build_description
  build_timeout = local.code_build_timeout
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:5.0"
    type         = "LINUX_CONTAINER"
  }

  source {
    type            = "CODECOMMIT"
    location        = data.aws_codecommit_repository.python_model_repository.clone_url_http
    git_clone_depth = 1

  buildspec = <<-EOT
    version: 0.2

    phases:
      install:
        runtime-versions:
          python: 3.8
        commands:
          - pip install -r requirements.txt
      build:
        commands:
          - aws s3 cp s3://${local.s3_bucket_name}/ tmp/ --recursive
          - python train.py
      post_build:
        commands:
          - aws s3 cp tmp/config.json s3://${local.s3_bucket_name}/config.json
          - aws s3 cp tmp/pytorch_model.bin s3://${local.s3_bucket_name}/pytorch_model.bin
  EOT
  }
}

resource "aws_iam_role" "codebuild" {
  name = "codebuild_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "codebuild_policy" {
  name        = "codebuild_policy"
  path        = "/"
  description = "Codebuild policy"
  policy      = file("${path.module}/codebuild_policy.json")
}

resource "aws_iam_role_policy_attachment" "codebuild_policy_attach" {
  role       = aws_iam_role.codebuild.name
  policy_arn = aws_iam_policy.codebuild_policy.arn
}

# CodePipeline setup

resource "aws_iam_role" "codepipeline" {
  name = "codepipeline_role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "codepipeline.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_policy" "codepipeline_policy" {
  name        = "codepipeline_policy"
  path        = "/"
  description = "Codepipeline policy"
  policy      = file("${path.module}/codepipeline_policy.json")
}

resource "aws_iam_role_policy_attachment" "codepipeline_policy_attach" {
  role       = aws_iam_role.codepipeline.name
  policy_arn = aws_iam_policy.codepipeline_policy.arn
}

resource "aws_codepipeline" "codepipeline" {
  name     = "codepipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = local.s3_bucket_name
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        S3Bucket    = local.s3_bucket_name
        S3ObjectKey = "train.json"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.python_model_build.name
      }
    }
  }
  depends_on = [
    aws_s3_bucket.model_data_bucket
  ]
}

resource "aws_iam_role" "pipeline_log_role" {
  name               = "pipeline_log_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action    = "sts:AssumeRole"
      },
    ]
  })
}

resource "aws_iam_role_policy" "pipeline_log_role" {
  name = "pipeline_log_role_policy"
  role = aws_iam_role.pipeline_log_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "*"
      },
    ]
  })
  depends_on = [
    aws_iam_role.pipeline_log_role
  ]
}

resource "aws_cloudwatch_log_group" "codepipeline" {
  name              = "/aws/codepipeline/sirius"
  retention_in_days = 7
  depends_on = [
    aws_iam_role_policy.pipeline_log_role
  ]
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.model_data_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck20150319"
        Action    = "s3:GetBucketAcl"
        Effect    = "Allow"
        Resource  = aws_s3_bucket.model_data_bucket.arn
        Principal = { 
          Service = "cloudtrail.amazonaws.com"
        }
      },
      {
        Sid       = "AWSCloudTrailWrite20150319"
        Action    = "s3:PutObject"
        Effect    = "Allow"
        Resource  = "${aws_s3_bucket.model_data_bucket.arn}/*"
        Principal = { 
          Service = "cloudtrail.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
  depends_on = [
    aws_s3_bucket.model_data_bucket
  ]
}

resource "aws_cloudtrail" "codepipeline" {
  name                          = "codepipeline"
  s3_bucket_name                = aws_s3_bucket.model_data_bucket.bucket
  enable_logging                = true
  enable_log_file_validation    = true
  include_global_service_events = true
  is_multi_region_trail         = false
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.codepipeline.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.pipeline_log_role.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type = "AWS::S3::Object"
      
      values = ["arn:aws:s3:::${local.s3_bucket_name}/train.json"]
    }
  }
  depends_on = [
    aws_codepipeline.codepipeline,
    aws_cloudwatch_log_group.codepipeline,
    aws_s3_bucket_policy.bucket_policy
  ]
}

resource "aws_cloudwatch_event_rule" "pipeline" {
  name        = "codepipeline"
  description = "Capture S3 Events to trigger CodePipeline"

  depends_on = [
    aws_codepipeline.codepipeline
  ]

  event_pattern = <<PATTERN
{
  "source": [
    "aws.s3"
  ],
  "detail-type": [
    "AWS API Call via CloudTrail"
  ],
  "detail": {
    "eventSource": [
      "s3.amazonaws.com"
    ],
    "eventName": [
      "PutObject"
    ],
    "requestParameters": {
      "bucketName": [
        "sirius-python-model-bucket"
      ],
      "key": [
        "train.json"
      ]
    }
  }
}
PATTERN
}

resource "aws_cloudwatch_event_target" "pipeline" {
  rule      = aws_cloudwatch_event_rule.pipeline.name
  target_id = "CodePipelineTarget"
  arn       = aws_codepipeline.codepipeline.arn
  role_arn = aws_iam_role.cloudwatch_event_role.arn
}

resource "aws_iam_role" "cloudwatch_event_role" {
  name = "cloudwatch-event-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = ""
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })

  depends_on = [
    aws_codepipeline.codepipeline
  ]

}

resource "aws_iam_role_policy" "cloudwatch_event_policy" {
  role   = aws_iam_role.cloudwatch_event_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = ""
        Effect = "Allow"
        Action = "codepipeline:StartPipelineExecution"
        Resource = aws_codepipeline.codepipeline.arn
      },
    ]
  })
}

# Lambda function setup

data "archive_file" "lambda_function_zip" {
  type        = "zip"
  source_file = "../../model/run.py"
  output_path = "../../model/run.zip"
}

resource "aws_lambda_function" "python_lambda" {
  function_name = "run-python-model"
  filename      = data.archive_file.lambda_function_zip.output_path
  role          = aws_iam_role.lambda_exec.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_permissions" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_exec.name
}

# API Gateway setup

resource "aws_apigatewayv2_api" "http_api" {
  name          = "HTTP_API"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.python_lambda.invoke_arn
}

resource "aws_apigatewayv2_route" "http_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "ANY /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "http_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "v1"
  description = "Version 1 of the API"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_gateway_permission" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.python_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

output "http_api_url" {
  value = aws_apigatewayv2_api.http_api.api_endpoint
}