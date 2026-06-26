  resource "aws_db_subnet_group" "main" {
    name       = "app-db-subnet-group"
    subnet_ids = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    tags       = { Name = "db-subnet-group" }
  }

  resource "aws_db_instance" "postgres" {
    identifier           = "app-migration-db"
    engine               = "postgres"
    engine_version       = "16.4"
    instance_class       = "db.t3.micro"
    allocated_storage    = 20
    storage_type         = "gp3"
    db_name              = "gitops_db"
    username             = "postgres"
    password             = var.db_password
    publicly_accessible  = false
    skip_final_snapshot  = true
    db_subnet_group_name = aws_db_subnet_group.main.name

    vpc_security_group_ids = [aws_security_group.rds_sg.id]
  }
