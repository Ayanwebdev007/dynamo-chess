# Dynamo Chess 2020 Documentation

Dynamo Chess 2020 is a premium, high-stakes chess variant application built with Flutter and Firebase. It features a unique 10x10 grid and modern strategic elements while maintaining a sleek, executive minimalist aesthetic.

## 🚀 Core Features

### 🎮 Game Modes
- **Player vs Player (Local)**: Classic two-player mode on a single device.
- **Play with AI**: Challenge the "Dynamo AI" with minimax-based move selection (Depth 2).
- **Online PvP**: Real-time multiplayer powered by Firebase Realtime Database.
- **Matchmaking & Challenges**: 
  - Open lobby for public matches.
  - Direct friend challenges via invitations.
  - Real-time notification system for challenges (In-app, Browser, and Audio).

### 🏆 Chess Variant Rules (10x10)
Dynamo Chess introduces unique mechanics that expand traditional strategy:
- **10x10 Grid**: A larger battlefield for deeper tactical planning.
- **The Missile**: A new strategic piece combining the moves of a **Bishop** and a **Knight** (Value: 7).
- **Enhanced Pawn Jumps**: Pawns can jump **1, 2, or 3 squares** on their initial move.
- **Advanced En-Passant**: Support for capturing pawns that jump past multiple squares.
- **Custom Piece Values**:
  - ♟️ **Pawn**: 1
  - ♞ **Knight**: 3
  - ♝ **Bishop**: 3
  - ♜ **Rook**: 5
  - 🚀 **Missile**: 7
  - ♛ **Queen**: 9

### 🌐 Online & Social
- **Real-time Synchronization**: Instant move updates and game state persistence.
- **Live Match Chat**: Full-featured in-game chat with notification badges and message overlays.
- **User Authentication**: Secure Login/Sign-up via Firebase Auth.
- **Player Profiles**: Track wins, losses, and user stats.
- **Notification History**: View and respond to past game invitations.

## 🎨 Design & UI/UX
The app follows an **Executive Minimalist** design language:
- **Aesthetic**: Deep dark backgrounds (`#0A0E0A`) with premium Gold accents (`#D4AF37`).
- **Dynamic Backgrounds**: Subtle animated radial gradients and glow effects.
- **Glassmorphism**: Translucent control panels and buttons for a modern feel.
- **Responsive Board**: Scalable 10x10 board with high-fidelity piece assets.
- **In-Game HUD**:
  - **Move History**: Visual log of all moves made.
  - **Captured Pieces**: Real-time tracking of captured material.
  - **Score Advantage**: Dynamic calculation of which player leads in material value.
  - **Clocks**: High-precision timers for various time controls (Bullet, Blitz, Rapid).

## 🛠️ Technical Architecture
- **Frontend**: Flutter (Dart) for cross-platform support (Web & Mobile).
- **Backend**: 
  - **Firebase Auth**: User management.
  - **Firebase Realtime DB**: High-speed game state and chat sync.
  - **Firebase Cloud Messaging**: Background challenge notifications.
- **Game Engine**:
  - `RulesEngine`: Custom-built logic for 10x10 variant rules.
  - `AIEngine`: Minimax search with alpha-beta pruning (optimized for casual play).
  - `FenConverter`: Specialized FEN string support for 10x10 boards.

## ⚙️ Customization
Users can tailor their experience via the **Settings Screen**:
- **Board Themes**: Multiple visual styles for the chess grid.
- **Move Hints**: Toggle legal move indicators.
- **Coordinates**: Show/Hide board rank and file labels.
- **Last Move Highlight**: Toggle visibility of the opponent's previous move.
- **Auto-Promote**: Option to automatically promote pawns to Queens.

---
*Documentation generated on May 5, 2026*
