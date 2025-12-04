# Assume 'module.bucket_label' and 'providers' are defined elsewhere

########################################################
# 1. DR Bucket Creation (us-east-2)
# Includes Replication back to Primary and MRAP setup
########################################################
module "my_s3_bucket_dr" {
  source = "github.com/hinge-health-terraform/aws_s3_bucket?ref=v3.5.0"

  providers = {
    aws = aws.us-east-2
  }

  context                = module.bucket_label.context
  name                   = "v3-bucket-dr"
  object_versioning_status = "Enabled"

  # Replication Configuration - replicate from DR bucket to source bucket
  replication_configuration = {
    rules = [
      {
        id                             = "ReplicateToSourceBucket"
        status                         = "Enabled"
        priority                       = 1
        delete_marker_replication_status = "Enabled"
        destinations = [
          {
            bucket_arn    = module.my_s3_bucket.bucket_arn
            storage_class = "STANDARD"
          }
        ]
        filter = {
          prefix = ""
        }
      }
    ]
  }

  replication_iam = {
    role_name               = "v3-bucket-dr-s3-replication-role"
    policy_name             = "v3-bucket-dr-s3-replication-policy"
    destination_bucket_arns = [module.my_s3_bucket.bucket_arn, module.my_s3_bucket_dr.bucket_arn]
  }

  mrap_name = "v3-bucket-mrap"

  # --- ACTIVE/PASSIVE MRAP CONFIGURATION START ---
  # These new variables are required for the routing script in your module
  mrap_regions = [
    {
      region                  = "us-east-1"
      bucket_arn              = module.my_s3_bucket.bucket_arn
      bucket_name             = module.my_s3_bucket.bucket_name     # <-- ADDED: Primary Bucket Name
      traffic_dial_percentage = 100                               # <-- ADDED: Primary Active
    },
    {
      region                  = "us-east-2"
      bucket_arn              = module.my_s3_bucket_dr.bucket_arn
      bucket_name             = module.my_s3_bucket_dr.bucket_name  # <-- ADDED: DR Bucket Name
      traffic_dial_percentage = 0                                 # <-- ADDED: DR Passive
    }
  ]
  # --- ACTIVE/PASSIVE MRAP CONFIGURATION END ---


  mrap_iam = {
    role_name        = "v3-bucket-mrap-role"
    policy_name      = "v3-bucket-mrap-policy"
    # Ensure bucket_arns are ARNs, not names
    bucket_arns      = [module.my_s3_bucket.bucket_arn, module.my_s3_bucket_dr.bucket_arn] 
    policy_path      = "/"
    policy_description = "IAM policy for Multi-Region Access Point to access v3-bucket and v3-bucket-dr"
  }
}

--------------------------------------------------------

########################################################
# 2. Primary S3 Bucket (us-east-1)
# Configures CRR from Source to DR
########################################################
module "my_s3_bucket" {
  source = "github.com/hinge-health-terraform/aws_s3_bucket?ref=v3.5.0"

  providers = {
    aws = aws.us-east-1
  }

  context                = module.bucket_label.context
  name                   = "v3-bucket"
  object_versioning_status = "Enabled"

  replication_configuration = {
    # Re-use the IAM role created by the DR module (which is located in us-east-2)
    iam_role_arn = module.my_s3_bucket_dr.replication_iam_role_arn 
    rules = [
      {
        id                             = "ReplicateToDRBucket"
        status                         = "Enabled"
        priority                       = 1
        delete_marker_replication_status = "Enabled"
        destinations = [
          {
            bucket_arn    = module.my_s3_bucket_dr.bucket_arn
            storage_class = "STANDARD"
          }
        ]
        filter = {
          prefix = ""
        }
      }
    ]
  }
}
