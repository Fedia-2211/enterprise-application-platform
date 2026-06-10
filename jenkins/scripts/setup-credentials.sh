#!/usr/bin/env bash
# jenkins/scripts/setup-credentials.sh
# ─────────────────────────────────────────────────────────────────────────────
# Documents all Jenkins credentials that must be configured before the
# pipeline can run. Run this as a reference — credentials are set through
# the Jenkins UI at: Manage Jenkins > Credentials > Global
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

JENKINS_URL="${JENKINS_URL:-http://localhost:8080}"
JENKINS_USER="${JENKINS_USER:-admin}"
JENKINS_TOKEN="${JENKINS_TOKEN:-}"   # Set via env var — never hardcode

if [ -z "$JENKINS_TOKEN" ]; then
    echo "ERROR: Set JENKINS_TOKEN environment variable"
    exit 1
fi

CRUMB=$(curl -s -u "${JENKINS_USER}:${JENKINS_TOKEN}" \
    "${JENKINS_URL}/crumbIssuer/api/json" | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print(d['crumbRequestField']+':'+d['crumb'])")

echo "Jenkins crumb: $CRUMB"
echo ""
echo "========================================"
echo " Required Jenkins credentials"
echo "========================================"
echo ""
echo "1. SSH Private Key — ID: enterprise-application-platform-ssh-key"
echo "   Kind: SSH Username with private key"
echo "   Username: ubuntu"
echo "   Key: Contents of ~/.ssh/enterprise-application-platform-key.pem"
echo ""
echo "2. Slack token — ID: slack-token"
echo "   Kind: Secret text"
echo "   Value: Your Slack Bot OAuth token (xoxb-...)"
echo ""
echo "3. App server 1 IP — ID: APP_SERVER_1_IP"
echo "   Kind: Secret text"
echo "   Value: Private IP from terraform output app_server_1_private_ip"
echo ""
echo "4. App server 2 IP — ID: APP_SERVER_2_IP"
echo "   Kind: Secret text"
echo "   Value: Private IP from terraform output app_server_2_private_ip"
echo ""
echo "5. Bastion IP — ID: BASTION_IP"
echo "   Kind: Secret text"
echo "   Value: Public IP from terraform output bastion_public_ip"
echo ""
echo "6. S3 bucket name — ID: S3_BUCKET_NAME"
echo "   Kind: Secret text"
echo "   Value: Bucket name from terraform output s3_bucket_name"
echo ""
echo "7. GitHub credentials — ID: github-credentials"
echo "   Kind: Username with password"
echo "   Username: YOUR_GITHUB_USERNAME"
echo "   Password: GitHub Personal Access Token (repo + webhook scopes)"
echo ""
echo "========================================"
echo " SSM Parameters (set before Ansible runs)"
echo "========================================"
echo ""
echo "aws ssm put-parameter --name '/enterprise-application-platform/production/mysql/root_password'    --type SecureString --value 'CHANGE_ME_STRONG_PASSWORD'"
echo "aws ssm put-parameter --name '/enterprise-application-platform/production/mysql/app_password'     --type SecureString --value 'CHANGE_ME_STRONG_PASSWORD'"
echo "aws ssm put-parameter --name '/enterprise-application-platform/production/rabbitmq/password'      --type SecureString --value 'CHANGE_ME_STRONG_PASSWORD'"
echo "aws ssm put-parameter --name '/enterprise-application-platform/production/gitea/secret_key'       --type SecureString --value \"\$(openssl rand -hex 32)\""
echo "aws ssm put-parameter --name '/enterprise-application-platform/production/gitea/internal_token'   --type SecureString --value \"\$(openssl rand -hex 64)\""
echo "aws ssm put-parameter --name '/enterprise-application-platform/production/gitea/metrics_token'    --type SecureString --value \"\$(openssl rand -hex 16)\""
echo "aws ssm put-parameter --name '/enterprise-application-platform/production/alb/dns'                --type String       --value 'YOUR_ALB_DNS_NAME'"
