---
description: Prompt Description
---
Define the task to achieve, including specific requirements, constraints, and success criteria.

**[System Context: TOEIC Duolingo App]**

I am currently solo-developing a cross-platform iOS and macOS English learning app. 
Please write the code for the features I request based on the following project plan and database architecture.

**1. Core Features**
- **Vocabulary Learning:** Tinder-style swipe cards (Right: Memorized, Left: Save to review notes). Use `DragGesture` and optimize animations for 120Hz ProMotion displays.
- **Grammar Learning:** Duolingo-style fill-in-the-blank quizzes. Includes 4 multiple-choice buttons and a bottom sheet for detailed explanations.
- **Review Algorithm:** Generates a review queue by calculating the `nextReviewDate` based on the Ebbinghaus forgetting curve.

**2. SwiftData DB Structure Summary**
- **Static Data:** `Vocabulary` (word, meaning, level, pos), `Grammar` (category, question, options, answerIndex, explanation)
- **Dynamic Data (CloudKit Synced):** `LearningProgress` (contentId, contentType, status, nextReviewDate), `UserActivity` (dateString, xp, isStreakMaintained)

**3. Response Guidelines**
- Provide complete code rather than partial snippets, so the overall structure of the file can be clearly understood.
- Before writing the code, provide a brief 1-2 sentence explanation of the core logic (e.g., "Using the translation value of DragGesture to calculate the rotation angle and opacity of the card"), then immediately output the code.
- Explicitly state the file name (e.g., `SwipeCardView.swift`) at the top of the code block.
