## 1. AWS Provider Configuration (Define Regions)
# These are required to deploy resources into the correct region when using for_each.

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "us-east-2"
  region = "us-east-2"
}



# --- 2. Data Sources (Look up existing Primary Buckets) ---
# This block iterates over the locals map to get the ARN for every existing Primary bucket.

data "aws_s3_bucket_arn" "primary" {
  for_each = local.dr_bucket_configurations
  # Explicitly use the primary region provider alias
  provider = aws.us-east-1 
  bucket   = each.value.primary_bucket_name
}

# --- 3. DR Bucket Creation, IAM, and MRAP Setup (Looped) ---
# This block creates 100 DR buckets, their IAM roles, and their MRAP configuration.

module "dr_s3_setup" {
  for_each = local.dr_bucket_configurations
  source   = "github.com/hinge-health-terraform/aws_s3_bucket?ref=v3.5.0"

  # The resource is always created in the DR region (us-east-2)
  providers = {
    aws = aws.us-east-2 
  }

  # Dynamic Naming and Context
  context                = module.bucket_label.context
  name                   = each.value.dr_bucket_name          # e.g., v3-reports-dr
  object_versioning_status = "Enabled"

  # --- CRR to Primary (Failback Configuration on DR Bucket) ---

  replication_configuration = {
    rules = [{
      id                             = "ReplicateToSourceBucket"
      status                         = "Enabled"
      priority                       = 1
      delete_marker_replication_status = "Enabled"
      destinations = [{
        # References the existing Primary bucket ARN via the data source
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
    # Destination ARNs needed for the IAM policy creation within the module
    destination_bucket_arns = [
      data.aws_s3_bucket_arn.primary[each.key].arn,
      "arn:aws:s3:::${each.value.dr_bucket_name}"
    ]
  }

  # --- ACTIVE/PASSIVE MRAP CONFIGURATION START ---
  mrap_name = "${each.key}-mrap" # e.g., marketing-reports-mrap
  mrap_regions = [
    {
      region                  = each.value.primary_region
      bucket_arn              = data.aws_s3_bucket_arn.primary[each.key].arn
      bucket_name             = each.value.primary_bucket_name
      traffic_dial_percentage = 100  # PRIMARY: Active
    },
    {
      region                  = each.value.dr_region
      bucket_arn              = module.dr_s3_setup[each.key].bucket_arn    # DR bucket output
      bucket_name             = each.value.dr_bucket_name
      traffic_dial_percentage = 0    # DR: Passive
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

# --- 4. CRR Configuration on Existing Primary Bucket (Looped) ---
# Since the Primary bucket exists, we must configure CRR separately using a resource block.

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
    
    # Destination is the newly created DR bucket
    destination {
      bucket = module.dr_s3_setup[each.key].bucket_arn
    }
  }
}
