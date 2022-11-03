# devops-infra-aws-tf-codepipeline
Terraform code to create AWS CodeBuild and CodePipeline along with a Lambda function to send Slack alerts

# Usage

To import to your Terraform project as a remote module:

1. Add SSH key for a user that has access to the remote repository

2. Reference the module (NOTE: set `ref` to the tag to install)

    ```Terraform
    module "codebuild-notification" {
      source = "git@github.com:Lenders-Cooperative/devops-infra-aws-tf-codepipeline.git//modules/codebuild_scaffold?ref=main"
    ```

3. `terraform init`

4. Set Terraform Variables

    * [modules/codebuild/variables.tf](modules/codebuild/variables.tf)
    * [modules/codebuild_scaffold/variables.tf](modules/codebuild_scaffold/variables.tf)

5. `terraform apply`