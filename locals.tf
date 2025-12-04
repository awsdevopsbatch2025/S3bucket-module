locals {
  # --- CONFIGURATION FOR ALL BUCKETS ---
  dr_bucket_configurations = {
    "marketing-reports" = {
      primary_region      = "us-east-1"
      dr_region           = "us-west-2"
      primary_bucket_name = "v3-reports-prod"
      dr_bucket_name      = "v3-reports-dr"
    },
    "user-uploads" = {
      primary_region      = "us-east-1"
      dr_region           = "us-west-2"
      primary_bucket_name = "v3-media-prod"
      dr_bucket_name      = "v3-media-dr"
    },
    # ... 98 more entries here ...
  }
}
