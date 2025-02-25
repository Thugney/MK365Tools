# Contributing to MK365Tools

## Development Workflow

### Branch Structure
- `main` - Production branch, stable releases only
- `development` - Development branch, work in progress
- Feature branches should be created from `development`

### Version Control
- Production versions use semantic versioning (e.g., `1.0.0`)
- Development versions use `-dev` suffix (e.g., `1.0.0-dev`)

### Development Process
1. Create a feature branch from `development`:
   ```powershell
   git checkout development
   git checkout -b feature/your-feature-name
   ```

2. Make your changes and test thoroughly

3. Commit your changes with semantic commit messages:
   ```powershell
   git commit -m "feat: Add new feature"
   git commit -m "fix: Fix bug in existing feature"
   git commit -m "docs: Update documentation"
   ```

4. Push your feature branch and create a pull request to `development`

5. After review and testing, merge to `development`

6. Periodically, `development` will be merged to `main` for releases

### Testing
1. Write tests for new features
2. Run all tests before committing:
   ```powershell
   Invoke-Pester .\Tests
   ```

3. Test in both Windows PowerShell and PowerShell Core

### Documentation
- Update relevant documentation in `usage.md`
- Add examples for new features
- Keep README.md current
- Document breaking changes

### Module Development
1. Update module manifest version
2. Test module import
3. Update function documentation
4. Verify dependencies

### Release Process
1. Update version numbers
2. Update changelog
3. Merge to main
4. Create release tag
5. Publish to PowerShell Gallery

## Code Style Guide

### PowerShell Conventions
- Use approved PowerShell verbs
- Follow noun-verb naming
- Use proper casing:
  - PascalCase for functions
  - camelCase for variables
  - UPPERCASE for constants

### Documentation
- Use comment-based help
- Include examples
- Document parameters
- Explain complex logic

### Error Handling
- Use try/catch blocks
- Implement proper error messages
- Use Write-Error for errors
- Use Write-Warning for warnings

### Security
- Never store credentials in code
- Use secure string for passwords
- Implement proper permission checks
- Follow least privilege principle
