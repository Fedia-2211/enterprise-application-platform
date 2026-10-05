# Running Ansible from the Bastion host

All six servers live in private subnets. Ansible runs from the Bastion host,
which is the only machine reachable over SSH from the internet (and only from
`your_ip_cidr`).

## 1. Connect to the Bastion

```bash
BASTION_IP=$(terraform -chdir=terraform/environments/production output -raw bastion_public_ip)
ssh -i ~/.ssh/enterprise-application-platform-key.pem ubuntu@"$BASTION_IP"
```

## 2. Install the tools (once per rebuild)

```bash
sudo apt update
sudo apt install -y python3-pip unzip
pip3 install ansible boto3 botocore

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip awscliv2.zip && sudo ./aws/install
```

The Bastion's IAM instance profile allows it to read the SSM parameters, so no
AWS keys are copied to the server.

## 3. Copy the SSH key and the Ansible code

Run these from your workstation:

```bash
# Generate the inventory and variables locally first
make inventory
cp ansible/inventories/production/group_vars/all.yml.example \
   ansible/inventories/production/group_vars/all.yml   # then edit s3_bucket

scp -i ~/.ssh/enterprise-application-platform-key.pem \
    ~/.ssh/enterprise-application-platform-key.pem ubuntu@"$BASTION_IP":~/.ssh/
scp -i ~/.ssh/enterprise-application-platform-key.pem -r ansible ubuntu@"$BASTION_IP":~/ansible
```

Then on the Bastion:

```bash
chmod 400 ~/.ssh/enterprise-application-platform-key.pem
cd ~/ansible
ansible-galaxy collection install -r requirements.yml
ansible all -m ping
ansible-playbook site.yml
```

> **Improvement idea:** use AWS SSM Session Manager instead of copying the SSH
> key to the Bastion, so no private key ever leaves the workstation.
