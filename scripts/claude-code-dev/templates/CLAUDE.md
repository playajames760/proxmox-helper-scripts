# Project: {{ PROJECT_NAME }}

## Overview
{{ PROJECT_DESCRIPTION }}

## Development Environment
This project is set up for Claude Code development with the following features:
- Node.js 20 LTS with npm, yarn, pnpm
- Modern development tools (ESLint, Prettier, TypeScript)
- VS Code Server integration
- Docker support for containerized development
- Git workflow with GPG signing

## Project Structure
```
{{ PROJECT_NAME }}/
├── src/                 # Source code
├── tests/              # Test files
├── docs/               # Documentation
├── scripts/            # Build and deployment scripts
├── .claude/            # Claude Code configuration
│   └── commands/       # Custom Claude commands
├── .vscode/            # VS Code settings
├── .github/            # GitHub workflows
├── package.json        # Node.js dependencies
├── tsconfig.json       # TypeScript configuration
├── .eslintrc.js        # ESLint configuration
├── .prettierrc         # Prettier configuration
├── .gitignore          # Git ignore rules
├── Dockerfile          # Docker configuration
├── docker-compose.yml  # Docker Compose setup
└── README.md           # Project documentation
```

## Getting Started
1. Install dependencies: `npm install`
2. Start development server: `npm run dev`
3. Run tests: `npm test`
4. Build for production: `npm run build`

## Claude Code Commands
This project includes custom Claude Code commands:
- `/project:test` - Run tests and analyze results
- `/project:build` - Build and optimize the project
- `/project:deploy` - Deploy to staging/production
- `/project:docs` - Generate or update documentation
- `/project:security` - Security audit and recommendations

## Development Workflow
1. Create feature branch: `git checkout -b feature/new-feature`
2. Use Claude Code for development: `claude "implement new feature"`
3. Run tests: `npm test`
4. Commit changes: `git commit -S -m "feat: add new feature"`
5. Push and create PR: `git push && gh pr create`

## Environment Variables
Copy `.env.example` to `.env` and configure:
- `NODE_ENV` - development/staging/production
- `PORT` - application port (default: 3000)
- `DATABASE_URL` - database connection string
- `API_KEY` - external API keys

## Debugging
- Use VS Code debugger with launch configurations in `.vscode/launch.json`
- Use Claude Code for error analysis: `claude "debug this error: [error message]"`
- Check logs: `npm run logs`

## Deployment
- Development: `npm run dev`
- Staging: `npm run deploy:staging`
- Production: `npm run deploy:production`

## Contributing
1. Follow conventional commit format
2. Use Claude Code for code review: `claude "review my changes"`
3. Ensure all tests pass
4. Update documentation as needed

## Useful Commands
- `claude-init <project>` - Initialize new project with Claude Code
- `dev [project]` - Navigate to project directory
- `new-project <type> <n>` - Create templated project
- `claude --continue` - Continue previous Claude Code session
- `gh pr create` - Create GitHub pull request