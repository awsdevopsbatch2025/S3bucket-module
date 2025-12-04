# --- Core Bucket Configuration ---

variable "name" {
  description = "The name for the S3 bucket."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for the bucket name."
  type        = string
  default     = ""
}

variable "name_uniqueness" {
  description = "Add a unique suffix to the bucket name."
  type        = bool
  default     = true
}

variable "context" {
  description = "Context for resource tagging and naming."
  type        = string
  default     = "s3-bucket"
}

variable "tags" {
  description = "Additional tags to apply to the bucket."
  type        = map(string)
  default     = {}
}

variable "private" {
  description = "Blocks public access controls (block_public_acls, block_public_policy, etc.)."
  type        = bool
  default     = true
}

variable "acl" {
  description = "The canned ACL to apply to the bucket (e.g., 'private', 'public-read'). Set to 'null' for BucketOwnerEnforced."
  type        = string
  default     = "private"
}

variable "policy" {
  description = "JSON string for the bucket policy."
  type        = string
  default     = ""
}

variable "force_destroy" {
  description = "A boolean that indicates all objects should be deleted from the bucket before the bucket is destroyed."
  type        = bool
  default     = false
}

variable "access_log_bucket" {
  description = "The bucket where access logs will be written."
  type        = string
  default     = null
}

variable "object_ownership" {
  description = "Specifies the S3 Object Ownership control ('BucketOwnerPreferred', 'ObjectWriter', or 'BucketOwnerEnforced')."
  type        = string
  default     = "BucketOwnerEnforced"
}

# --- Encryption ---

variable "kms_master_key_id" {
  description = "The ARN or ID of the AWS KMS master key to use for default encryption."
  type        = string
  default     = null
}

# --- Versioning and Object Lock ---

variable "object_versioning_status" {
  description = "The versioning status (e.g., 'Enabled', 'Suspended')."
  type        = string
  default     = "Enabled"
}

variable "object_lock_enabled" {
  description = "A boolean to enable Object Lock for the bucket."
  type        = bool
  default     = false
}

variable "object_lock_default_retention_period" {
  description = "The number of days or years for default retention."
  type        = number
  default     = 0
}

variable "object_lock_default_retention_units" {
  description = "The retention period unit ('Days' or 'Years')."
  type        = string
  default     = "Days"
}

# --- Lifecycle Rules ---

variable "lifecycle_rules" {
  description = "Additional lifecycle rules to apply."
  type        = list(any)
  default     = []
}

variable "noncurrent_object_expiration_days" {
  description = "Specifies the number of days after which noncurrent versions should expire."
  type        = number
  default     = 0
}

variable "incomplete_multipart_expiration_days" {
  description = "Specifies the number of days after which incomplete multipart uploads should be aborted."
  type        = number
  default     = 0
}

variable "object_expiration_days" {
  description = "Specifies the number of days after which objects should expire."
  type        = number
  default     = 0
}

variable "temporary_object_expiration_days" {
  description = "Specifies the number of days after which objects under prefix 'temporary/' or tag lifecycle=temporary should expire."
  type        = number
  default     = 0
}

variable "warm_tier_transition_days" {
  description = "Specifies the number of days after which to move objects to the warm storage class."
  type        = number
  default     = 0
}

variable "warm_tier_storage_class" {
  description = "The warm storage class to transition objects to."
  type        = string
  default     = "INTELLIGENT_TIERING"
}

variable "warm_tier_minimum_size" {
  description = "Minimum object size in bytes for warm tier transition."
  type        = number
  default     = 131072
}

variable "cold_tier_transition_days" {
  description = "Specifies the number of days after which to move objects to the cold storage class."
  type        = number
  default     = 0
}

variable "cold_tier_storage_class" {
  description = "The cold storage class to transition objects to."
  type        = string
  default     = "GLACIER_IR"
}

variable "cold_tier_minimum_size" {
  description = "Minimum object size in bytes for cold tier transition."
  type        = number
  default     = 131072
}

variable "archive_object_transition_days" {
  description = "Specifies the number of days after which to move objects to the archive storage class."
  type        = number
  default     = 0
}

# --- Replication Configuration (CRR) ---

variable "replication_configuration" {
  description = "Configuration block for cross-region replication."
  type        = any # Using 'any' for complex nested replication rules
  default     = null
}

variable "replication_iam" {
  description = "Configuration for the IAM role and policy used for replication."
  type        = any # Using 'any' for complex IAM structures
  default     = null
}

# --- Metrics ---

variable "bucket_metrics_filters" {
  description = "A map of metric filter configurations."
  type        = map(object({ prefix = string }))
  default     = {}
}

# --------------------------------------------------------------------------------
# --- MULTI-REGION ACCESS POINT (MRAP) CONFIGURATION ---
# --------------------------------------------------------------------------------

variable "mrap_name" {
  description = "The name of the Multi-Region Access Point. If null, MRAP is not created."
  type        = string
  default     = null
}

variable "mrap_regions" {
  description = "List of regions/buckets associated with the MRAP, including routing configuration."
  type = list(object({
    region                  = string
    bucket_arn              = string
    bucket_name             = string  # <-- REQUIRED for the Active/Passive routing logic
    traffic_dial_percentage = optional(number, 100) # <-- REQUIRED for Active/Passive (0 for Passive, 100 for Active)
  }))
  default = []
}

variable "mrap_iam" {
  description = "Configuration for the IAM role and policy used for the MRAP."
  type        = any # Using 'any' for complex IAM structures
  default     = null
}

# --------------------------------------------------------------------------------
# --- DR / PERMISSION MIRRORING CONFIGURATION ---
# --------------------------------------------------------------------------------

variable "mirrored_acl" {
  description = "The canned ACL of the primary bucket to be mirrored (e.g., 'private'). This overrides the standard 'acl' variable if set."
  type        = string
  default     = null # Set to null to make it optional, allowing the root to pass `null` if the data source fails to retrieve it or if not mirroring is intended.
}

variable "mirrored_versioning_status" {
  description = "The versioning status ('Enabled' or 'Suspended') of the primary bucket to be mirrored. This is used instead of 'object_versioning_status' for DR buckets."
  type        = string
  default     = "Enabled" # Default to 'Enabled' if not explicitly passed, though passing the source status is highly recommended.
}

variable "mirrored_pab_config" {
  description = "Public Access Block configuration (block_public_acls, etc.) fetched from the primary bucket to be mirrored."
  type = object({
    block_public_acls       = bool
    block_public_policy     = bool
    ignore_public_acls      = bool
    restrict_public_buckets = bool
  })
  # Set defaults to false to match the API expectation if no configuration is found, 
  # though the root should always pass the full object.
  default = {
    block_public_acls       = false
    block_public_policy     = false
    ignore_public_acls      = false
    restrict_public_buckets = false
  }
}
