terraform {
  backend "s3" {
    bucket = "genlogs-tf-state-file"
    key    = "aws/components/network/vpc.tfstate"
    region = "us-east-1"
  }
}
