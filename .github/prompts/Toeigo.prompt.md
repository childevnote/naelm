---
description: Prompt Description
---
Define the task to achieve, including specific requirements, constraints, and success criteria.

[Context & Rules]

Language/Framework: Swift 5.9+, SwiftUI (Latest), SwiftData.

Target: iOS 17.0+, macOS 14.0+ cross-platform.

Architecture: MVVM (Model-View-ViewModel) or modern SwiftUI patterns utilizing observable state (@Observable).

[Coding Guidelines]

Write all UI components in SwiftUI and break them down into small, reusable pieces.

Use SwiftData's @Model for persistent data storage.

Actively utilize animations and transitions, but ensure they are implemented without causing performance degradation.

Minimize explanations and prioritize providing clean, well-commented code that can be immediately copied, pasted, and executed.

If the UI needs to differ between macOS and iOS, include branching logic using #if os(macOS) or similar directives.
