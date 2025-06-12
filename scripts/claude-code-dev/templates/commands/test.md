# Test Project Command

Please run the following testing workflow:

1. **Install Dependencies**: Run `npm install` to ensure all dependencies are up to date
2. **Lint Code**: Run `npm run lint` to check code style and quality
3. **Type Check**: Run `npm run type-check` if TypeScript is configured
4. **Unit Tests**: Run `npm test` to execute unit tests
5. **Integration Tests**: Run `npm run test:integration` if available
6. **Coverage Report**: Run `npm run test:coverage` to generate coverage report
7. **Performance Tests**: Run `npm run test:performance` if configured

After running tests:
- Analyze any failing tests and suggest fixes
- Review test coverage and recommend improvements
- Identify performance bottlenecks if any
- Suggest additional tests if needed

If any step fails, diagnose the issue and provide solutions.

Arguments: $ARGUMENTS (e.g., "unit", "integration", "coverage")