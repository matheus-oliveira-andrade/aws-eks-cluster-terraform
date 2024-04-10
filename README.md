### AWS EKS Cluster Setup with Terraform

Creates an AWS EKS cluster with one node using spot instance

### Requirements

To create resources you will need:
  - [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
  - [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html#getting-started-install-instructions)

### How run 

1 - Check if AWS credentials are updated
  ```sh
  > aws s3 ls --profile dev
  output:
  2023-10-18 19:51:18 0occ8l-ukk5id
  2023-01-14 20:11:41 2v8gh8-e8x3cur
  ```

2 - Download modules used in [`main.tf`](main.tf)
  ```sh
  > terraform init
  ```

3 - See resources will be created
  ```sh
  > terraform plan
  ```

4 - Create resources
  ```sh
  > terraform apply
  ```