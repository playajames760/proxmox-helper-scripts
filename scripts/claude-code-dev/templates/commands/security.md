# Security Audit Command

Please perform a comprehensive security audit:

1. **Dependency Audit**:
   - Run `npm audit` to check for known vulnerabilities
   - Review dependency licenses with `npm run license-check`
   - Check for outdated packages: `npm outdated`
   - Analyze dependency tree for suspicious packages

2. **Code Security Review**:
   - Scan for hardcoded secrets and API keys
   - Review authentication and authorization logic
   - Check input validation and sanitization
   - Identify potential injection vulnerabilities
   - Review error handling for information leakage

3. **Configuration Security**:
   - Audit environment variable usage
   - Review security headers configuration
   - Check HTTPS/TLS configuration
   - Verify secure cookie settings
   - Review CORS configuration

4. **Infrastructure Security**:
   - Review Docker container security
   - Check file permissions and access controls  
   - Verify secrets management practices
   - Review deployment security practices

5. **Generate Security Report**:
   - Document all findings with severity levels
   - Provide remediation recommendations
   - Create action items for security improvements
   - Suggest security best practices to implement

Focus on actionable recommendations and prioritize high-severity issues.

Arguments: $ARGUMENTS (e.g., "dependencies", "code", "config", "infrastructure")