# Overview

This project is an electronic queue management system designed for government and commercial institutions. It provides web-based appointment booking, terminal ticket dispensing, operator queue management, and display screens for real-time queue status. A key feature is the integration of a local AI assistant via Ollama for task automation, data analysis, and chat support. The system utilizes a full-stack architecture with a React frontend, an Express.js backend, a PostgreSQL database (hosted on Neon), and real-time WebSocket communication. The project aims to streamline queue management operations, enhance user experience, and provide actionable insights through AI.

# User Preferences

Preferred communication style: Simple, everyday language.

## UI/UX Preferences

- Compact design with no wasted space
- Left sidebar with collapsible sections for management interfaces
- Design pattern: Follow services design layout for consistency
- Quick actions in overview should include AI chat and import functionality
- Active operators display instead of no-shows with clickable status details

## Security Requirements

- Web registration page (/booking) must be completely isolated - no navigation to other pages allowed
- Only exit through browser back/close buttons for security purposes
- Removed Navigation component from booking page to prevent access to other system modules
- Dual-access architecture: internal network gets full access, external access limited to booking page

# System Architecture

## Frontend Architecture
The frontend is built with React 18 and TypeScript, leveraging Shadcn/ui and Radix UI for a modern, component-based user interface styled with Tailwind CSS. Wouter is used for client-side routing. TanStack Query manages server state, enabling efficient data fetching, caching, and real-time synchronization via WebSocket integration for live queue updates.

## Backend Architecture
The backend uses Express.js with TypeScript to provide a RESTful API server. Drizzle ORM ensures type-safe database operations with PostgreSQL and manages schema migrations. A dedicated WebSocket server handles real-time bidirectional communication for queue status updates. The architecture features a modular service layer, including an Ollama AI service and WebSocket management.

## Database Design
PostgreSQL, hosted on Neon, is the chosen database. It features a comprehensive relational schema encompassing departments, services, operators, appointments, tickets, call history, ratings, AI chat logs, display boards, and voice settings, with proper foreign key relationships. Session management is handled via PostgreSQL.

## Authentication & Authorization
The system implements role-based access control for operator, admin, and supervisor roles, each with distinct permission levels. Session-based authentication is used, with server-side sessions stored in PostgreSQL. Passwords for operator accounts are securely hashed.

## Real-time Features
WebSocket integration provides live updates for queue status, ticket calls, and operator actions across multi-client interfaces (dashboard, terminal, operator, display, admin). Event broadcasting ensures real-time notifications to all connected clients upon queue state changes.

## AI Integration
A local LLM is integrated via the Ollama service, providing configurable models and module-specific contexts. The AI adapts responses based on the module type and organizational scope, with an admin interface for model selection, temperature control, and context editing. All AI interactions are logged for auditing and improvement.

## Queue Management Features
The system supports multi-modal ticket issuance, including web appointments with PIN codes and walk-in terminal tickets with 80mm thermal printing. Services are configurable with estimated times and department assignments. Operators manage the complete ticket lifecycle, from calling to completion, with rating collection. A two-column display system shows active and assigned tickets. The system also includes analytics dashboards, electronic display board integration via COM port ($E0 protocol) for displaying ticket numbers, and automated display management.

## Deployment Features
The system supports comprehensive deployment across multiple platforms with automated installation scripts. The enhanced installer provides full production deployment for Linux distributions (Ubuntu, Debian, CentOS, RHEL, Rocky Linux, AlmaLinux) with automatic OS detection, dependency resolution, PostgreSQL setup, Nginx configuration, Systemd service integration, security hardening (UFW, fail2ban), and RHVoice voice engine installation. Additional deployment scripts include: quick development setup, database reset/restoration, and complete database initialization with Roskazna organization data. All scripts feature error recovery, comprehensive logging, backup creation, and health monitoring with detailed installation reports.

# External Dependencies

## Database & Infrastructure
- **Neon PostgreSQL**: Serverless PostgreSQL database hosting.
- **WebSocket (ws)**: Library for real-time bidirectional communication.

## AI & Machine Learning
- **Ollama**: Local LLM server for AI capabilities.
- **Axios**: HTTP client for API communication, including with Ollama.

## Frontend Libraries
- **React & React DOM**: Core UI library.
- **TanStack React Query**: Server state management.
- **React Hook Form + Zod**: Form handling and validation.
- **Wouter**: Client-side routing.
- **Radix UI**: Accessible component primitives.
- **Tailwind CSS**: Utility-first CSS framework.

## Backend Dependencies
- **Express.js**: Web application framework.
- **Drizzle ORM**: Type-safe database toolkit for PostgreSQL.
- **Connect PG Simple**: PostgreSQL session store for Express.
- **Date-fns**: Date manipulation and formatting.

## Development Tools
- **Vite**: Build tool and development server.
- **TypeScript**: Static type checking.
- **ESBuild**: Fast JavaScript bundler.
- **PostCSS & Autoprefixer**: CSS processing.