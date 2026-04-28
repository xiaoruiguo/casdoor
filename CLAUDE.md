# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Casdoor is an open-source AI-first Identity and Access Management (IAM) / AI MCP gateway and auth server with web UI supporting MCP, A2A, OAuth 2.1, OIDC, SAML, CAS, LDAP, SCIM, WebAuthn, TOTP, MFA, Face ID, Google Workspace, Azure AD.

## Architecture Overview

This is a Go-based web application with a React frontend:

### Backend (Go)
- Main entry point: `main.go`
- Core components organized in packages:
  - `controllers/`: HTTP handlers for API endpoints
  - `object/`: Business logic and data models
  - `log/`: Logging implementations for different platforms
  - `conf/`: Configuration management
  - `util/`: Utility functions
  - `routers/`: HTTP routing setup
  - `authz/`: Authorization logic using Casbin
  - `ldap/`, `radius/`: Authentication service integrations

### Frontend (React)
- Located in `web/` directory
- Build and run commands:
  - `npm start` (Run development server)
  - `npm run build` (Build for production)
  - `npm test` (Run frontend tests)
- Uses Create React App and CRACO (Create React App Configuration Override)
- Uses `src/` for components and pages
- `public/` for static assets

## Key Development Commands

### Build
```bash
make backend        # Build backend binary
make frontend       # Build frontend
make docker-build   # Build Docker image
make all            # Build everything
```

### Test
```bash
make ut             # Run unit tests
make lint           # Run linters
```

### Run
```bash
make run            # Run backend locally
make deps           # Start dependencies (database)
```

### Development
```bash
make fmt            # Format Go code
make vet            # Vet Go code
make vendor         # Update vendor dependencies
```

## Key Files and Directories

### Core Files
- `main.go`: Application entry point
- `go.mod`: Go module dependencies
- `Makefile`: Build and development commands
- `Dockerfile`: Container build configuration
- `README.md`: Project documentation

### Configuration
- `conf/app.conf`: Main configuration file
- `web/package.json`: Frontend dependencies and scripts

### Logging
- `log/` directory contains platform-specific logging implementations

## Authentication and Authorization

- Uses Casbin for authorization with RBAC model
- Supports multiple authentication methods: OAuth 2.1, OIDC, SAML, CAS, LDAP, SCIM, WebAuthn, TOTP, MFA, Face ID
- Implements JWT and OAuth token handling
- Supports LDAP and RADIUS authentication integrations

## Key Features

1. **Multi-factor Authentication**: TOTP, SMS, Email, WebAuthn, Face ID
2. **Single Sign-On**: OAuth, OIDC, SAML, CAS, LDAP integrations
3. **Identity Provider**: Google Workspace, Azure AD, Keycloak, etc.
4. **Access Control**: RBAC with Casbin, fine-grained permissions
5. **Payment Integration**: Stripe, PayPal, etc.
6. **Webhooks**: Event-driven architecture
7. **Multi-language Support**: Internationalization with i18next

## Development Workflow

1. Start local database: `make deps`
2. Run backend: `make run`
3. Build frontend: `make frontend` (or use `yarn build` in `web/` directory)
4. Test: `make ut` or `go test ./...`
5. Lint: `make lint`

## Docker Deployment

The project includes Docker build configurations:
- Multi-stage Docker build with separate frontend and backend stages
- Supports both standard and all-in-one container images
- Uses Alpine Linux for standard image, Debian for all-in-one

## Key Go Packages

- `github.com/beego/beego/v2`: Web framework
- `github.com/casbin/casbin/v2`: Authorization library
- `github.com/go-sql-driver/mysql`: MySQL driver
- `github.com/golang-jwt/jwt/v5`: JWT handling
- `github.com/prometheus/client_golang`: Prometheus metrics