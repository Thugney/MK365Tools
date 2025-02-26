# Changelog

All notable changes to this project will be documented in this file.

## [1.1.0] - 2025-02-26

### Added
- New MK365SchoolManager module for school-specific device management
  - Device inventory tracking and reporting
  - Automated device reset workflows
  - School-specific configuration management
  - Integration with education-specific features
- New Graph module dependencies:
  - Microsoft.Graph.DeviceManagement.Administration (v2.26.1)
  - Microsoft.Graph.DeviceManagement.Functions (v2.26.1)
  - Microsoft.Graph.DeviceManagement.Enrollment (v2.26.1)

### Changed
- Updated all Microsoft Graph PowerShell SDK dependencies to v2.26.1
  - Microsoft.Graph.Authentication
  - Microsoft.Graph.DeviceManagement
  - Microsoft.Graph.Identity.DirectoryManagement
  - Microsoft.Graph.Users
  - Microsoft.Graph.Groups
  - Microsoft.Graph.Beta.DeviceManagement
  - Microsoft.Graph.Intune
  - Microsoft.Graph.Identity.SignIns
- Updated Microsoft.Graph.DeviceManagement.Actions to v2.25.0
- Standardized module version requirements across all modules
- Improved module version consistency in manifest files
- Enhanced documentation with quick start guides and examples
- Updated installation instructions for all modules

### Documentation
- Added comprehensive documentation for MK365SchoolManager
- Updated main README with school management features
- Added quick start guides for all modules
- Improved module dependency documentation
- Enhanced branch management and development workflow

### Development
- Established proper branch management workflow
  - Development branch for feature work
  - Main branch for stable releases
  - Clean merge history maintained
- Improved version control practices
- Enhanced commit message clarity

## [Unreleased]

### Added
- Created development branch structure
- Added comprehensive usage documentation with real-world scenarios
- Added CONTRIBUTING.md with development workflow guidelines
- Added template files for bulk operations
- Added new user management scripts

### Changed
- Updated MK365DeviceManager to use latest Graph API cmdlets
- Updated MK365UserManager with enhanced functionality
- Improved error handling and logging across modules
- Updated module manifests with development versions
- Enhanced documentation with practical examples

### Development Setup
- Established main/development branch workflow
- Added version control guidelines
- Created development environment configuration

## [1.0.0] - 2025-02-25

### Added
- Initial release of MK365Tools
- MK365DeviceManager module
  - Device management features
  - Security monitoring
  - Autopilot integration
  - Application deployment tracking
- MK365UserManager module
  - User lifecycle management
  - Security and access control
  - Group management
  - Bulk operations support

### Documentation
- Added comprehensive README
- Added usage documentation
- Added code examples and templates
