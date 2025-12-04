## 1. AWS Provider Configuration (Define Regions)
# These providers are necessary for the for_each loops to deploy resources across us-east-1 and us-east-2.

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "us-east-2"
  region = "us-east-2"
}

# Assume 'module.bucket_label' is defined elsewhere and is singular.

# --------------------------------------------------------------------------------------------------

## 2. Data Sources (Look up existing Primary Bucket Properties)
# These blocks fetch the current configuration of the existing production buckets.

# Look up the ARN for all existing Primary buckets
data "aws_s3_bucket_arn" "primary" {
  for_each = local.dr_bucket_configurations
  provider = aws.us-east-1 
  bucket   = each.value.primary_bucket_name
}

# Look up general bucket properties (e.g., versioning status)
data "aws_s3_bucket" "primary_properties" {
  for_each = local.dr_bucket_configurations
  provider = aws.us-east-1 
  bucket   = each.value.primary_bucket_name
}

# Look up Public Access Block configuration
data "aws_s3_bucket_public_access_block" "primary_pab" {
  for_each = local.dr_bucket_configurations
  provider = aws.us-east-1
  bucket   = each.value.primary_bucket_name
}

# Look up ACL (e.g., private, public-read)
data "aws_s3_bucket_acl" "primary_acl" {
  for_each = local.dr_bucket_configurations
  provider = aws.us-east-1
  bucket   = each.value.primary_bucket_name
}

# --------------------------------------------------------------------------------------------------

## 3. DR Bucket Creation, IAM, and MRAP Setup (Looped)
# This module block creates the DR bucket and sets up the shared replication/MRAP logic.

module "dr_s3_setup" {
  for_each = local.dr_bucket_configurations
  source   = "github.com/hinge-health-terraform/aws_s3_bucket?ref=v3.5.0"

  # The resource is always created in the DR region (us-east-2)
  providers = {
    aws = aws.us-east-2 
  }

  # Dynamic Naming and Context
  context                = module.bucket_label.context
  name                   = each.value.dr_bucket_name
  
  # --- REFLECTED PROPERTIES from Primary Bucket ---
  # Reflect the ACL (e.g., private, public-read)
  acl = data.aws_s3_bucket_acl.primary_acl[each.key].acl
  
  # Reflect the Versioning Status
  object_versioning_status = data.aws_s3_bucket.primary_properties[each.key].versioning[0].status 
  
  # Reflect website configuration (using try() to handle cases where it's not set on primary)
  website_configuration = try(
    {
      index_document = data.aws_s3_bucket.primary_properties[each.key].website[0].index_document
      error_document = data.aws_s3_bucket.primary_properties[each.key].website[0].error_document
    },
    null
  )
  # ------------------------------------------------

  # --- CRR to Primary (Failback Configuration on DR Bucket) ---
  replication_configuration = {
    rules = [{
      id                             = "ReplicateToSourceBucket"
      status                         = "Enabled"
      priority                       = 1
      delete_marker_replication_status = "Enabled"
      destinations = [{
        bucket_arn    = data.aws_s3_bucket_arn.primary[each.key].arn 
        storage_class = "STANDARD"
      }]
      filter = { prefix = "" }
    }]
  }

  # Dynamic IAM Role/Policy Naming
  replication_iam = {
    role_name               = "${each.value.dr_bucket_name}-s3-replication-role"
    policy_name             = "${each.value.dr_bucket_name}-s3-replication-policy"
    destination_bucket_arns = [
      data.aws_s3_bucket_arn.primary[each.key].arn,
      "arn:aws:s3:::${each.value.dr_bucket_name}"
    ]
  }

  # --- ACTIVE/PASSIVE MRAP CONFIGURATION START ---
  mrap_name = "${each.key}-mrap"
  mrap_regions = [
    {
      region                  = each.value.primary_region
      bucket_arn              = data.aws_s3_bucket_arn.primary[each.key].arn
      bucket_name             = each.value.primary_bucket_name
      traffic_dial_percentage = 100
    },
    {
      region                  = each.value.dr_region
      bucket_arn              = module.dr_s3_setup[each.key].bucket_arn
      bucket_name             = each.value.dr_bucket_name
      traffic_dial_percentage = 0
    }
  ]
  # --- ACTIVE/PASSIVE MRAP CONFIGURATION END ---

  mrap_iam = {
    role_name        = "${each.key}-mrap-role"
    policy_name      = "${each.key}-mrap-policy"
    bucket_arns      = [data.aws_s3_bucket_arn.primary[each.key].arn, module.dr_s3_setup[each.key].bucket_arn]
    policy_path      = "/"
    policy_description = "IAM policy for Multi-Region Access Point to access ${each.value.primary_bucket_name} and ${each.value.dr_bucket_name}"
  }
}

# --------------------------------------------------------------------------------------------------

## 4. Public Access Block Configuration (Looped)
# This block applies the Public Access Block settings, mirroring the primary bucket's security.

resource "aws_s3_bucket_public_access_block" "dr_pab" {
  for_each = local.dr_bucket_configurations
  
  # Resource must run in the DR region (us-east-2)
  provider = aws.us-east-2
  
  bucket = module.dr_s3_setup[each.key].bucket_id

  # Reflect all Public Access Block settings from the Primary bucket
  block_public_acls       = data.aws_s3_bucket_public_access_block.primary_pab[each.key].block_public_acls
  block_public_policy     = data.aws_s3_bucket_public_access_block.primary_pab[each.key].block_public_policy
  ignore_public_acls      = data.aws_s3_bucket_public_access_block.primary_pab[each.key].ignore_public_acls
  restrict_public_buckets = data.aws_s3_bucket_public_access_block.primary_pab[each.key].restrict_public_buckets
}

# --------------------------------------------------------------------------------------------------

## 5. CRR Configuration on Existing Primary Bucket (Looped)
# This block configures the Primary bucket to replicate data to the new DR bucket.

resource "aws_s3_bucket_replication_configuration" "primary_to_dr" {
  for_each = local.dr_bucket_configurations
  
  # Resource must run in the Primary region (us-east-1)
  provider = aws.us-east-1
  
  bucket = each.value.primary_bucket_name
  # Uses the IAM role created by the corresponding DR module instance
  role   = module.dr_s3_setup[each.key].replication_iam_role_arn 

  rule {
    id     = "ReplicateToDRBucket"
    status = "Enabled"
    priority = 1
    
    destination {
      bucket = module.dr_s3_setup[each.key].bucket_arn
    }
  }
}
