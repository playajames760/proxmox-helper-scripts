# Deploy Project Command

Please handle the deployment workflow:

1. **Pre-deployment Checks**:
   - Verify current branch is main/master or release branch
   - Ensure all tests pass: `npm test`
   - Check build succeeds: `npm run build`
   - Verify no uncommitted changes: `git status`

2. **Environment Setup**:
   - Check environment variables are configured
   - Verify deployment target is accessible
   - Confirm backup procedures are in place

3. **Deployment Process**:
   - Create deployment branch if needed
   - Tag release: `git tag v$(npm version --json | jq -r .version)`
   - Push to deployment target
   - Run deployment scripts
   - Verify deployment health checks

4. **Post-deployment**:
   - Run smoke tests on deployed application
   - Monitor logs for errors
   - Update documentation with deployment notes
   - Notify team of successful deployment

Arguments: $ARGUMENTS (e.g., "staging", "production", "rollback")

Handle rollback procedures if deployment fails.