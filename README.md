# AWS Resources Report Script

This PowerShell script generates a report of AWS resources across multiple profiles, detailing their public/private IP addresses and DNS names. The report is saved in both CSV and XLSX formats. The script depends on the `aws-sso-util` tool to manage AWS SSO login and works with profiles defined in a `profiles.txt` file.

## Prerequisites

1. **AWS Reader Access Across Organization**: At least reader rights is required across your orgniazation or individual accounts.
2. **AWS CLI**: Ensure that the AWS CLI is installed. If not, the script will prompt to install it.
3. **aws-sso-util**: This script requires `aws-sso-util` to manage AWS Single Sign-On (SSO) logins. Follow the installation instructions at [aws-sso-util GitHub](https://github.com/benkehoe/aws-sso-util).
4. **PowerShell**: The script should be executed in a PowerShell environment.

## Features

- **Profiles**: The script reads AWS profiles from a `profiles.txt` file. Each profile is processed individually.
- **Resource Collection**: The script gathers information about the following AWS resources:
  - EC2 Instances
  - RDS Instances
  - Elastic Load Balancers (ELBs)
  - Elastic IPs (EIPs)
  - Elastic Network Interfaces (ENIs)
  - ECS Clusters and Services
  - EKS Clusters
  - Lambda Functions (with VPC configurations)
- **CSV and Excel Export**: The script exports the collected data into a CSV file and converts it to an Excel (.xlsx) file.

## Script Workflow

1. **AWS CLI Check**: The script checks if the AWS CLI is installed. If not, it prompts the user to install it automatically.
2. **aws-sso-util Check**: The script ensures `aws-sso-util` is installed, directing the user to the installation guide if necessary.
3. **Login to AWS**: The script logs into all AWS accounts configured for the specified profiles using `aws-sso-util`.
4. **AWS Resource Report**: The script iterates over each profile and collects the following resource information:
   - Account ID
   - Resource type (e.g., EC2, RDS, ELB)
   - Resource IDs
   - Public and private IP addresses (if applicable)
   - DNS names (if applicable)
   - VPC IDs
5. **File Export**: The report is generated in both CSV and XLSX formats with a timestamped filename.

## Usage

1. **Clone the repository** and navigate to the script directory.
2. **Set up your AWS profiles**:
   - Create a `profiles.txt` file in the same directory as the script. List the AWS profile names you want to include, one per line.
3. **Run the Script**:
   - Execute the script in PowerShell.
   - Example:
     ```powershell
     .\RainingAWSIPs.ps1
     ```
4. **Check the Output**:
   - The report will be saved as a CSV and an Excel file in the user's home directory with the current date included in the filename.

## Requirements

- **aws-cli**: The script will attempt to install the AWS CLI if not found.
- **aws-sso-util**: Follow the [installation guide](https://github.com/benkehoe/aws-sso-util).
- **PowerShell**: Ensure you are running this in a Windows environment with Excel installed (for Excel export functionality).

## Notes

- This script assumes the user has permissions to access all AWS resources for each profile specified.
- The `aws-sso-util login --all` command logs in to all AWS accounts in your configuration files.
- Lambda functions connected to VPCs will report ENI details, as Lambda functions don't have public IPs.
  
## Troubleshooting

- **AWS CLI installation issues**: If the script fails to install the AWS CLI, you can manually download and install it from [AWS CLI V2](https://aws.amazon.com/cli/).
- **Profile errors**: Ensure your `profiles.txt` file is correctly formatted and the AWS CLI is configured with valid profiles.
- **Excel export**: Ensure Excel is installed and available to PowerShell for proper XLSX export.

## License

This script is licensed under the MIT License.
