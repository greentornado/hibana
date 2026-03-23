# Contributing to Hibana

Thank you for your interest in contributing to Hibana!

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/your-username/hibana.git`
3. Install dependencies: `mix deps.get`
4. Run tests: `cd apps/hibana && MIX_ENV=test mix test`

## Development Workflow

1. Create a feature branch: `git checkout -b feature/my-feature`
2. Make your changes
3. Add tests for new functionality
4. Run the formatter: `mix format`
5. Run tests to ensure nothing is broken
6. Commit your changes with a clear message
7. Push to your fork and open a Pull Request

## Code Style

- Run `mix format` before committing
- Follow standard Elixir conventions
- Add `@moduledoc` and `@doc` for public modules and functions
- Write tests for all new features

## Reporting Issues

- Use the GitHub issue templates
- Include steps to reproduce for bugs
- Include Elixir and OTP versions

## Pull Requests

- Keep PRs focused on a single change
- Update documentation if applicable
- Add tests for new functionality
- Reference related issues in the PR description

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
