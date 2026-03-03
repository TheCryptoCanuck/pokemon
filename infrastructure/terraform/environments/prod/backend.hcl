bucket         = "aviquest-terraform-state"
region         = "us-east-1"
key            = "aviquest/prod/terraform.tfstate"
dynamodb_table = "aviquest-terraform-locks"
encrypt        = true
