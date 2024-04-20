### AWS EKS Cluster Setup with Terraform

Setting up an AWS EKS cluster with addons like coredns, kube-proxy, and vpc-cni, utilizing terraform modules [terraform-aws-modules/eks/aws](https://github.com/terraform-aws-modules/terraform-aws-eks) and [terraform-aws-modules/vpc/aws](https://github.com/terraform-aws-modules/terraform-aws-vpc). It  also includes configuring the AWS load balancer controller

### Requirements

To create resources you will need:
  - [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
  - [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html#getting-started-install-instructions)
  - [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)

### How run 

1 - Creation of resources

  * Check for terraform remote backend in s3 exists

     is required exist a s3 with name expected in [version.tf](versions.tf)
     ```sh
     aws s3 ls --profile default
     # Example output:
     # 2023-10-18 19:51:18 terraform-state-516735145595     
     ``` 

  * Download modules used in [`main.tf`](main.tf)
    ```sh
    terraform init
    ```

  * Preview the resources that will be created
    ```sh
    terraform plan
    ```

  * Create the resources
    ```sh
    # Estimated time to create all resources: 20 minutes
    terraform apply 
    ```

2 - Update kubeconfig File

Update your kubeconfig file to access the created cluster
```sh
# update config file in ~/.kube
aws eks update-kubeconfig --name apps --region us-east-1
```

3 - Communicate with the Cluster

Use kubectl to interact with your cluster
```sh
# get all resources created in kubernetes
kubectl get all -A
```