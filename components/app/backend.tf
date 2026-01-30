terraform {
  backend "s3" {
    bucket = "genlogs-tf-state-file"
    key    = "aws/components/app/app.tfstate"
    region = "us-east-1"
  }
}
