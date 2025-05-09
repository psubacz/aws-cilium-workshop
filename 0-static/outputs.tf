output "cluster_bucket_id" {
  value       = module.cluster_bucket.s3_bucket_id
  description = "The name of the bucket."
}
