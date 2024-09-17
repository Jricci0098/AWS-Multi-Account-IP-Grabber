#This script depends on aws-sso-util from https://github.com/benkehoe/aws-sso-util

#Check if aws cli is installed
if (!(Get-Command -Name 'aws' -ErrorAction SilentlyContinue)) {
    Write-Host "aws cli is not installed."
    $response = Read-Host -Prompt "Would you like to install it now?" -AsSecureString | ConvertFrom-SecureString
    if ($response -eq 'Y') {
        msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi /quiet /norestart
    } else {
        Write-Host "Skipping aws cli installation."
        exit 1 
    }
} else {
    Write-Host "aws cli is already installed."
}


#Check if aws-sso-util is installed
if (!(Get-Command -Name "aws-sso-util" -ErrorAction SilentlyContinue)) {
    Write-Host "aws-sso-util is not installed. This is required before we can proceed further."
    Write-Host "Follow the installation and configuration instructions at https://github.com/benkehoe/aws-sso-util"
    exit 1
    } else {
        Write-Host "aws-sso-util is installed...moving forward."
    }

#Login to AWS Accounts in your config files) 
aws-sso-util login --all

# Define the path for the CSV output file
$currentDate = (Get-Date).ToString("yyyy-MM-dd")
$outputCsv = "~\$currentDate-aws-resources.csv"

### Set input and output path
$inputCSV = $outputCsv
$outputXLSX = "~\$currentDate-aws-resources.xlsx"

# Define the profiles to iterate over
[string[]]$profiles = Get-Content "~/profiles.txt"

# Create the CSV file and define the headers
"AccountID,Service,ResourceID,PublicIP,PrivateIP,DNSName,VPCID" | Out-File $outputCsv

foreach ($profile in $profiles) {
$profile
    $accountId = (Get-STSCallerIdentity -ProfileName $profile).Account

    # EC2 instances
    $ec2Instances = Get-EC2Instance -ProfileName $profile
    foreach ($instance in $ec2Instances.Instances) {
        $instancePublicIp = $instance.PublicIpAddress
        $instancePrivateIp = $instance.PrivateIpAddress
        $instanceDnsName = $instance.PublicDnsName
        $instanceVpcId = $instance.VpcId
        $instanceId = $instance.InstanceId

        "$accountId,EC2,$instanceId,$instancePublicIp,$instancePrivateIp,$instanceDnsName,$instanceVpcId" | Out-File $outputCsv -Append
    }

    # RDS instances
    $rdsInstances = Get-RDSDBInstance -ProfileName $profile
    foreach ($dbInstance in $rdsInstances.DBInstances) {
        $dbInstancePublicIp = $dbInstance.Endpoint.Address
        $dbInstancePrivateIp = $null  # RDS does not provide a Private IP, you would need to use the DNS resolution within the VPC
        $dbInstanceDnsName = $dbInstance.Endpoint.Address
        $dbInstanceVpcId = $dbInstance.DBSubnetGroup.VpcId
        $dbInstanceId = $dbInstance.DBInstanceIdentifier

        "$accountId,RDS,$dbInstanceId,$dbInstancePublicIp,$dbInstancePrivateIp,$dbInstanceDnsName,$dbInstanceVpcId" | Out-File $outputCsv -Append
    }

    # Elastic Load Balancers
    $elbLoadBalancers = Get-ELBLoadBalancer -ProfileName $profile
    foreach ($elb in $elbLoadBalancers) {
        $elbDnsName = $elb.DNSName
        $elbVpcId = $elb.VPCId

        "$accountId,ELB,$elb.LoadBalancerName,,$elbDnsName,$elbVpcId" | Out-File $outputCsv -Append
    }

    # Elastic IPs
    $eips = Get-EC2Address -ProfileName $profile
    foreach ($eip in $eips) {
        $allocationId = $eip.AllocationId
        $publicIp = $eip.PublicIp
        $privateIp = $eip.PrivateIpAddress
        $associatedInstanceId = $eip.InstanceId

        "$accountId,EIP,$allocationId,$publicIp,$privateIp,,$associatedInstanceId" | Out-File $outputCsv -Append
    }

    # Elastic Network Interfaces (ENIs)
    $enis = Get-EC2NetworkInterface -ProfileName $profile
    foreach ($eni in $enis.NetworkInterfaces) {
        $eniId = $eni.NetworkInterfaceId
        $eniPublicIp = $eni.Association.PublicIp
        $eniPrivateIp = $eni.PrivateIpAddress
        $eniDnsName = $eni.Association.PublicDnsName
        $eniVpcId = $eni.VpcId

        "$accountId,ENI,$eniId,$eniPublicIp,$eniPrivateIp,$eniDnsName,$eniVpcId" | Out-File $outputCsv -Append
    }

    # ECS Clusters
    $ecsClusters = Get-ECSClusters -ProfileName $profile
    foreach ($cluster in $ecsClusters.Clusters) {
        $clusterServices = Get-ECSService -Cluster $cluster.ClusterName -ProfileName $profile
        foreach ($service in $clusterServices.Services) {
            $serviceEnis = Get-ECSTask -Cluster $cluster.ClusterName -ServiceName $service.ServiceName -ProfileName $profile | 
                           Get-ECSTaskDetail -ProfileName $profile | 
                           Select-Object -ExpandProperty Attachments | 
                           Select-Object -ExpandProperty Details | 
                           Where-Object { $_.Name -eq 'networkInterfaceId' }

            foreach ($eni in $serviceEnis) {
                $networkInterface = Get-EC2NetworkInterface -NetworkInterfaceId $eni.Value -ProfileName $profile
                $eniPublicIp = $networkInterface.Association.PublicIp
                $eniPrivateIp = $networkInterface.PrivateIpAddress
                $eniDnsName = $networkInterface.Association.PublicDnsName
                $eniVpcId = $networkInterface.VpcId

                "$accountId,ECS,$service.ServiceName,$eniPublicIp,$eniPrivateIp,$eniDnsName,$eniVpcId" | Out-File $outputCsv -Append
            }
        }
    }

    # EKS Clusters
    $eksClusters = Get-EKSClusterlist -ProfileName $profile
    foreach ($cluster in $eksClusters.Clusters) {
        $clusterName = $cluster.Name
        $endpoint = $cluster.Endpoint
        $vpcId = $cluster.ResourcesVpcConfig.VpcId

        "$accountId,EKS,$clusterName,,$endpoint,$vpcId" | Out-File $outputCsv -Append
    }

    # Lambda functions with VPC
    $lambdaFunctions = Get-LMFunctionList -ProfileName $profile
    foreach ($function in $lambdaFunctions.Functions) {
        if ($function.VpcConfig -and $function.VpcConfig.SubnetIds) {
            $functionEnis = Get-LMFunctionConfiguration -FunctionName $function.FunctionName -ProfileName $profile | 
                            Select-Object -ExpandProperty VpcConfig | 
                            Select-Object -ExpandProperty VpcId

            foreach ($eni in $functionEnis) {
                # Lambda functions don't have public IPs, but they may have ENIs if connected to a VPC.
                $eniDetails = Get-EC2NetworkInterface -Filter @{Name='group-id';Values=$eni.SecurityGroupIds} -ProfileName $profile
                foreach ($eniDetail in $eniDetails) {
                    $eniPrivateIp = $eniDetail.PrivateIpAddress
                    $eniDnsName = $eniDetail.PrivateDnsName
                    $eniVpcId = $eniDetail.VpcId

                    "$accountId,Lambda,$function.FunctionName,,$eniPrivateIp,$eniDnsName,$eniVpcId" | Out-File $outputCsv -Append
                }
            }
        }
    }
}


Write-Host "AWS resources IP/DNS report generated at $outputCsv"

# Create a new Excel Workbook with one empty sheet
$excel = New-Object -ComObject excel.application 
$workbook = $excel.Workbooks.Add(1)
$worksheet = $workbook.worksheets.Item(1)

# Build the QueryTables.Add command
# QueryTables does the same as when clicking "Data » From Text" in Excel
$TxtConnector = ("TEXT;" + $inputCSV)
$Connector = $worksheet.QueryTables.add($TxtConnector,$worksheet.Range("A1"))
$query = $worksheet.QueryTables.item($Connector.name)

# Set the delimiter (, or ;) according to your regional settings
$query.TextFileOtherDelimiter = $Excel.Application.International(5)

# Set the format to delimited and text for every column
# A trick to create an array of 2s is used with the preceding comma
$query.TextFileParseType  = 1
$query.TextFileColumnDataTypes = ,2 * $worksheet.Cells.Columns.Count
$query.AdjustColumnWidth = 1

# Execute & delete the import query
$query.Refresh()
$query.Delete()

# Save & close the Workbook as XLSX. Change the output extension for Excel 2003
$Workbook.SaveAs($outputXLSX,51)
$excel.Quit()
