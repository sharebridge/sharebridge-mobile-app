# sharebridge-mobile-app

> Mobile application (React Native/Flutter)

## Overview

This repository contains the **cross-platform mobile application** for ShareBridge, serving both donors and alms seekers.

**Key Features:**
- 📱 Donor interface: Quick order placement, location validation, order tracking
- 🙋 Seeker interface: QR code generation, location sharing, delivery confirmation
- 📸 Camera integration for photo verification
- 🗺️ Real-time location services and safety assessment
- 🔔 Push notifications for order status updates
- 🌐 Multi-language support (English, Tamil, Hindi, regional languages)
- 🎨 Accessible design for users with varying literacy levels

**Technology Stack:** React Native or Flutter (TBD based on community input)

For overall project context, see the [main ShareBridge repository](https://github.com/sharebridge/sharebridge).

## AI-Powered Development

This project uses AI-assisted development. Code and documentation are generated through prompts stored in the /prompting folder.

## Prompting Folder

The prompting/ folder contains:
- All prompts used to generate code for this component
- Feature requests and requirements in natural language
- AI model instructions and specifications
- Prompt templates for future development

**Transparency:** Anyone can see how features were specified and generated.  
**Reproducibility:** Use similar prompts to regenerate or modify components.  
**Collaboration:** Non-coders can contribute by writing or refining prompts.

## Repository Status

🚧 **Status:** Initial Setup  
📅 **Date:** January 9, 2026

## Getting Started

> Coming soon - Development setup instructions

## Contributing

See the [main repository's CALL_FOR_CONTRIBUTORS.md](https://github.com/sharebridge/sharebridge/blob/main/development/CALL_FOR_CONTRIBUTORS.md) for:
- How to contribute (technical and non-technical)
- Joining GitHub Discussions
- Submitting prompts and feature ideas

## Day-1 Flutter Scaffold (MVP Kickoff)

This repository now includes a lightweight Flutter starter scaffold for AI-assisted donor setup:

- `lib/features/donor_setup/` - domain, application, data, presentation layers
- `test/features/donor_setup/` - initial usecase, DTO, UI widget, and HTTP client tests
- `lib/features/donor_setup/data/donor_setup_api_exceptions.dart` - typed API exceptions
- `lib/features/donor_setup/data/http_donor_setup_api_client.dart` - HTTP client with configurable timeout and exponential-backoff retry policy

Run locally:

```bash
flutter pub get
flutter test
```

Run app with configurable backend URL:

```bash
# Windows desktop (backend on same machine)
flutter run --dart-define=API_BASE_URL=http://localhost:8080

# Android emulator (maps host machine localhost)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080

# Physical device (use your machine LAN IP)
flutter run --dart-define=API_BASE_URL=http://192.168.1.25:8080
```

Design reference sequence:
- `sharebridge/design/Donor_Setup_AI_Search_Sequence.md`
- Contract reference:
  - `https://github.com/sharebridge/sharebridge/blob/main/design/contracts/donor_setup_suggest_vendors.openapi.yaml`

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

Part of the [ShareBridge](https://github.com/sharebridge/sharebridge) ecosystem
