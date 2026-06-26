resource "aws_ecr_repository" "app_repo" {
  name                 = "app-migration-repo"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}