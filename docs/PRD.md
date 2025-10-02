# Product Requirements Document (PRD): Veramo - AI Couples App MVP

| Field | Value |
| :--- | :--- |
| **Product Name** | Veramo - AI Couples App |
| **Document Version** | 1.2 (Updated with Technical Stack) |
| **Owner** | Veramo Team |
| **Target Platforms** | iOS (Native/SwiftUI) |
| **Release Goal** | Define and implement the core Create, Share, and View loop with AI-powered image generation. |
| **Success Metric (High-Level)** | Daily Streak Completion (Users add an image to the Shared Calendar). |

---

## I. Product Overview & Core Value

The core value proposition is **AI-Powered Curation and Personalization** for couples' shared memories. The application provides a private workspace for partners to create or edit photos using AI tools before intentionally sharing them to a **Shared Calendar**, which feeds the daily **Widget**.

---

## II. Functional Requirements (What to Build)

### A. iOS Client Screens (SwiftUI)

The application will use a standard tab-based navigation with the following core screens:

| Screen Name | Priority | Core Functionality Required |
| :--- | :--- | :--- |
| **1. Home / Our Calendar (Today View)** | **MUST** | Displays the latest image shared to the **Shared Calendar** for the current date. Should support images of varying aspect ratios. |
| **2. Create New Memory** | **MUST** | Hub screen for creation. Provides clear navigation to: **AI Prompting** (Screen 3) or **My Gallery** (Screen 4). |
| **3. AI Prompt & Customization** | **MUST** | **Input Field:** Accepts free-form text prompts. **Image Seed:** Allows selecting an existing image from **My Gallery** to use as an AI style/content reference. **Style Selection:** Horizontal list of AI style presets (e.g., Cartoon, Dreamy). **Generation Button:** Calls the Backend AI Endpoint (Section III.A). Saves result to **My Gallery**. |
| **4. My Gallery / Simple Editor** | **MUST** | **Private Image Grid:** Displays *only* the current user's uploaded, edited, or AI-generated images. **Edit/Crop Tool:** Must open a simple editor with **Crop** and **Text Overlay** functionality (using Core Image / Core Graphics). Saving an edit creates a *new* image. **Share Action:** Button/Action to initiate sharing to the **Sharing Screen** (Screen 5). |
| **5. Sharing Screen (Confirm & Schedule)** | **MUST** | **Image Preview:** Displays the chosen image. **Date Picker:** Allows scheduling the image for any future date. **Logic Implementation:** The image is marked for shared viewing *only* after midnight on the selected date. **Commit Button:** Finalizes the share to the **Shared Calendar** (Database). |
| **6. Our Timeline (Full Calendar View)** | **MUST** | **Calendar Grid:** Monthly view showing a marker on every date that has a shared image. **Day View:** Tapping a marked date displays all images shared for that specific day. |
| **7. Login / Onboarding** | **MUST** | Standard user authentication flow. (Details to be added later) |
| **8. Settings** | **SHOULD** | Functionality for **Log Out**, viewing **Subscription Status**, and **Pairing with a Partner** (via shared code). |

### B. Core Features & Behaviors

| Feature | Requirement | Logic |
| :--- | :--- | :--- |
| **Account Pairing** | Users must pair accounts via a unique, shared code. | Person 1 generates code → Person 2 enters code → Person 1 accepts → linked. Either can remove link from settings. |
| **Image Privacy** | Uploaded/Generated images are **personal** by default. | Only the owner can view images in **My Gallery**. Images remain visible to owner even when scheduled for future calendar. |
| **The Streak** | Track the consecutive days an image has been added to the **Shared Calendar**. | Streak increments if *at least one* image is shared by *either* partner to the calendar on a given day. |
| **Image Editor Implementation** | Editor must be simple (Crop, Resize, Text Overlay). | Utilize **Core Image** for efficiency and **Core Graphics** for view rendering/capture. |
| **Subscription Sharing** | One partner subscribes → other partner automatically gets access. | No manual claiming needed. Subscription entitlement shared automatically between linked partners. |
| **Free Trial** | 3-day free trial before paywall. | Handled by Apple/Adapty integration. No backend tracking required. |

---

## III. Non-Functional & Technical Requirements

### A. Backend & Infrastructure

| Component | Technology | Requirement |
| :--- | :--- | :--- |
| **Database/Auth/Storage** | **Supabase** | Used for **User Auth**, **Database** (metadata, streaks, calendar), and **Image Storage** (S3-compatible bucket). |
| **AI Endpoint** | **Google Cloud Run Functions** | A single, scalable endpoint to receive the user's prompt and optional seed image path. |
| **AI Logic** | **Fal.ai Models** | Three model types: 1) Text-to-image generation, 2) Single image + text → new image, 3) Multiple images + text → edited image. Endpoint selects appropriate model based on request type. |
| **Image Asset Flow** | Client receives secure upload URL $\rightarrow$ Client uploads image to Supabase Storage $\rightarrow$ Client saves image metadata + storage path to Supabase DB. |

### B. iOS & Design

| Requirement | Specification |
| :--- | :--- |
| **OS Compatibility** | Target **iOS 26** (minimum recommended). |
| **Core Design** | Primary visual style must adhere to **iOS 26's Liquid Glass aesthetic** (using **SwiftUI** features). Non-liquid glass (standard translucency, opaque materials) **fallbacks must be implemented for earlier supported iOS versions.** |
| **Development & Deployment** | Project must be built and configured for publishing through **Xcode**. |
| **Paywall Integration** | Must integrate the **Adapty.io SDK** for subscription and paywall management. |

### C. Widget Requirements (WidgetKit)

| Feature | Requirement |
| :--- | :--- |
| **Widget Type** | Small or Medium Lock Screen/Home Screen Widget. |
| **Content** | Displays the **latest image** added to the **Shared Calendar** for the current date by the partner. |
| **Behavior** | Image updates dynamically. If no image is available for today, show a default image or the Streak Tracker. Tapping the widget opens the **Home Screen**. |
