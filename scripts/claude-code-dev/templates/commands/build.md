# Build Project Command

Please execute the following build workflow:

1. **Clean Previous Build**: Run `npm run clean` or remove build directories
2. **Install Dependencies**: Run `npm ci` for clean install
3. **Type Check**: Verify TypeScript compilation with `npm run type-check`
4. **Lint Code**: Ensure code quality with `npm run lint`
5. **Run Tests**: Execute `npm test` to verify functionality
6. **Build Application**: Run `npm run build` to create production build
7. **Optimize Assets**: Run asset optimization if configured
8. **Generate Documentation**: Run `npm run docs` if available
9. **Verify Build**: Test the built application works correctly

After building:
- Analyze build output for optimization opportunities
- Check bundle size and suggest improvements
- Verify all assets are properly generated
- Test the production build locally

Report any build errors with suggested solutions and optimizations.

Arguments: $ARGUMENTS (e.g., "development", "production", "staging")