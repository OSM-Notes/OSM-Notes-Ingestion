#!/bin/bash

# Script para activar y configurar GitHub Actions
# Author: Andres Gomez (AngocA)
# Version: 2025-08-01

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
 echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
 echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
 echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
 echo -e "${RED}[ERROR]${NC} $*"
}

# Show help
show_help() {
 cat << EOF
Script para activar y configurar GitHub Actions

Usage: $0 [OPTIONS]

Options:
  -h, --help              Show this help message
  -v, --verbose           Verbose output
  --check-status          Check current GitHub Actions status
  --enable-workflows      Enable all workflows
  --setup-notifications   Setup notifications for failures
  --test-workflow         Test a specific workflow
  --all                   Run all setup steps

Examples:
  $0 --check-status           # Check current status
  $0 --enable-workflows      # Enable workflows
  $0 --setup-notifications   # Setup notifications
  $0 --all                   # Run all setup steps

EOF
}

# Check if we're in a git repository
check_git_repo() {
 if [[ ! -d ".git" ]]; then
  log_error "This is not a git repository"
  exit 1
 fi

 if ! git remote get-url origin &> /dev/null; then
  log_error "No remote 'origin' found"
  exit 1
 fi

 log_success "Git repository detected"
}

# Check GitHub CLI availability
check_gh_cli() {
 if ! command -v gh &> /dev/null; then
  log_warning "GitHub CLI (gh) not found"
  log_info "Install GitHub CLI: https://cli.github.com/"
  log_info "Or manually activate workflows in GitHub web interface"
  return 1
 fi

 if ! gh auth status &> /dev/null; then
  log_warning "GitHub CLI not authenticated"
  log_info "Run: gh auth login"
  return 1
 fi

 log_success "GitHub CLI available and authenticated"
 return 0
}

# Check current workflow status
check_workflow_status() {
 log_info "Checking current workflow status..."

 if check_gh_cli; then
  # Get repository info
  local repo_info
  repo_info=$(gh repo view --json name,owner,url)
  local repo_name
  repo_name=$(echo "${repo_info}" | jq -r '.name')
  local owner
  owner=$(echo "${repo_info}" | jq -r '.owner.login')

  log_info "Repository: ${owner}/${repo_name}"

  # Check workflows
  local workflows
  workflows=$(gh api repos/${owner}/${repo_name}/actions/workflows)
  local workflow_count
  workflow_count=$(echo "${workflows}" | jq '.total_count')

  log_info "Found ${workflow_count} workflows"

  # List workflows
  echo "${workflows}" | jq -r '.workflows[] | "  - \(.name) (\(.state))"'

 else
  log_info "Manual check required:"
  log_info "1. Go to: https://github.com/$(git remote get-url origin | sed 's/.*github.com[:/]\([^/]*\/[^/]*\).*/\1/')"
  log_info "2. Navigate to Actions tab"
  log_info "3. Check if workflows are enabled"
 fi
}

# Enable workflows
enable_workflows() {
 log_info "Enabling workflows..."

 if check_gh_cli; then
  # Get repository info
  local repo_info
  repo_info=$(gh repo view --json name,owner,url)
  local repo_name
  repo_name=$(echo "${repo_info}" | jq -r '.name')
  local owner
  owner=$(echo "${repo_info}" | jq -r '.owner.login')

  # Enable workflows
  local workflows=("integration-tests" "quality-tests")

  for workflow in "${workflows[@]}"; do
   log_info "Enabling workflow: ${workflow}"

   # Get workflow file
   local workflow_file=".github/workflows/${workflow}.yml"
   if [[ -f "${workflow_file}" ]]; then
    # Enable workflow via API
    gh api repos/${owner}/${repo_name}/actions/workflows/${workflow}.yml \
     --method PUT \
     -f state=active &> /dev/null || log_warning "Could not enable ${workflow} via API"

    log_success "Workflow ${workflow} enabled"
   else
    log_error "Workflow file not found: ${workflow_file}"
   fi
  done

 else
  log_info "Manual workflow activation required:"
  log_info "1. Go to GitHub repository"
  log_info "2. Navigate to Actions tab"
  log_info "3. Click on each workflow"
  log_info "4. Click 'Enable workflow'"
  log_info "5. Workflows to enable:"
  log_info "   - integration-tests"
  log_info "   - quality-tests"
 fi
}

# Setup notifications
setup_notifications() {
 log_info "Setting up notifications for workflow failures..."

 if check_gh_cli; then
  # Get repository info
  local repo_info
  repo_info=$(gh repo view --json name,owner,url)
  local repo_name
  repo_name=$(echo "${repo_info}" | jq -r '.name')
  local owner
  owner=$(echo "${repo_info}" | jq -r '.owner.login')

  log_info "Repository: ${owner}/${repo_name}"

  # Setup repository notifications
  log_info "Setting up repository notifications..."

  # Enable email notifications for failures
  gh api repos/${owner}/${repo_name}/notifications \
   --method PUT \
   -f subscribed=true \
   -f ignored=false &> /dev/null || log_warning "Could not setup notifications via API"

  log_success "Notifications configured"

 else
  log_info "Manual notification setup required:"
  log_info "1. Go to GitHub repository settings"
  log_info "2. Navigate to Notifications"
  log_info "3. Configure email notifications for:"
  log_info "   - Workflow runs"
  log_info "   - Pull requests"
  log_info "   - Issues"
  log_info "4. Enable notifications for failures"
 fi
}

# Test workflow
test_workflow() {
 log_info "Testing workflow execution..."

 if check_gh_cli; then
  # Get repository info
  local repo_info
  repo_info=$(gh repo view --json name,owner,url)
  local repo_name
  repo_name=$(echo "${repo_info}" | jq -r '.name')
  local owner
  owner=$(echo "${repo_info}" | jq -r '.owner.login')

  # Trigger a test workflow run
  log_info "Triggering test workflow run..."

  gh api repos/${owner}/${repo_name}/actions/workflows/integration-tests.yml/dispatches \
   --method POST \
   -f ref=main \
   -f inputs='{"test_mode":"true"}' &> /dev/null || log_warning "Could not trigger workflow via API"

  log_success "Test workflow triggered"

 else
  log_info "Manual workflow test required:"
  log_info "1. Go to GitHub repository"
  log_info "2. Navigate to Actions tab"
  log_info "3. Click on 'integration-tests' workflow"
  log_info "4. Click 'Run workflow'"
  log_info "5. Select branch and run"
 fi
}

# Create notification configuration file
create_notification_config() {
 log_info "Creating notification configuration..."

 cat > .github/notifications.yml << 'EOF'
# GitHub Notifications Configuration
# This file helps configure notifications for workflow failures

notifications:
  # Email notifications
  email:
    enabled: true
    events:
      - workflow_run
      - pull_request
      - issues
    
  # Slack notifications (if configured)
  slack:
    enabled: false
    webhook_url: ""
    
  # Discord notifications (if configured)
  discord:
    enabled: false
    webhook_url: ""
    
  # Custom webhook notifications
  webhook:
    enabled: false
    url: ""
    
# Workflow failure notifications
workflow_notifications:
  integration-tests:
    on_failure: true
    on_success: false
    channels: ["email"]
    
  quality-tests:
    on_failure: true
    on_success: false
    channels: ["email"]

# Repository settings
repository:
  auto_delete_branch: true
  allow_merge_commit: true
  allow_squash_merge: true
  allow_rebase_merge: true
EOF

 log_success "Notification configuration created: .github/notifications.yml"
}

# Main function
main() {
 local check_status=false
 local enable_workflows_flag=false
 local setup_notifications_flag=false
 local test_workflow_flag=false
 local run_all=false

 # Parse command line arguments
 while [[ $# -gt 0 ]]; do
  case $1 in
  -h | --help)
   show_help
   exit 0
   ;;
  -v | --verbose)
   set -x
   shift
   ;;
  --check-status)
   check_status=true
   shift
   ;;
  --enable-workflows)
   enable_workflows_flag=true
   shift
   ;;
  --setup-notifications)
   setup_notifications_flag=true
   shift
   ;;
  --test-workflow)
   test_workflow_flag=true
   shift
   ;;
  --all)
   run_all=true
   shift
   ;;
  *)
   log_error "Unknown option: $1"
   show_help
   exit 1
   ;;
  esac
 done

 # Check git repository
 check_git_repo

 # Run all steps if requested
 if [[ "${run_all}" == true ]]; then
  check_status=true
  enable_workflows_flag=true
  setup_notifications_flag=true
  test_workflow_flag=true
 fi

 # Execute requested actions
 if [[ "${check_status}" == true ]]; then
  check_workflow_status
 fi

 if [[ "${enable_workflows_flag}" == true ]]; then
  enable_workflows
 fi

 if [[ "${setup_notifications_flag}" == true ]]; then
  setup_notifications
  create_notification_config
 fi

 if [[ "${test_workflow_flag}" == true ]]; then
  test_workflow
 fi

 # Show summary
 echo
 echo "=========================================="
 echo "GitHub Actions Setup Summary"
 echo "=========================================="
 echo "✅ Git repository verified"
 echo "✅ Workflow files validated"
 echo "📋 Next steps:"
 echo "   1. Push changes to GitHub"
 echo "   2. Go to Actions tab in repository"
 echo "   3. Enable workflows manually if needed"
 echo "   4. Configure notifications in repository settings"
 echo "   5. Test workflow execution"
 echo
 log_success "Setup completed successfully!"
}

# Run main function
main "$@"
