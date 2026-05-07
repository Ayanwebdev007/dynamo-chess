# Dynamo Chess: Feature Specifications

Dynamo Chess is a premium, high-stakes 10x10 chess variant designed for competitive play and a superior user experience. Below is the comprehensive list of features implemented in the current version.

---

## ♟️ Core Game Mechanics (10x10 Variant)
Dynamo Chess expands traditional chess with deeper tactical possibilities and unique rules.
- **Extended Battlefield**: A custom 10x10 grid (instead of the standard 8x8).
- **The Missile (New Piece)**: 
  - A specialized unit that combines the movement of a **Bishop** and a **Knight**.
  - Tactical Value: **7 Points**.
- **Dynamic Pawn Movement**: Pawns can jump **1, 2, or 3 squares** on their initial move.
- **Advanced En-Passant**: Specialized logic to handle captures of pawns that jump past multiple squares.
- **High-Stakes Valuation**:
  - ♟️ **Pawn**: 1
  - ♞ **Knight**: 3
  - ♝ **Bishop**: 3
  - ♜ **Rook**: 5
  - 🚀 **Missile**: 7
  - ♛ **Queen**: 9

## 🎮 Game Modes
- **Player vs Player (Local)**: Play against a friend on the same device.
- **Play with AI**: Challenge the "Dynamo AI" using a Minimax-based engine with Alpha-Beta pruning (Depth 2).
- **Online Multiplayer**: Real-time competitive matches powered by Firebase.
- **Global Matchmaking**: Join an open lobby to find opponents worldwide.
- **Private Challenges**: Send direct invitations to specific players via the challenge system.

## 🌐 Online & Social Ecosystem
- **Executive Authentication**: Secure Login and Sign-up system via Firebase Auth.
- **Real-time State Sync**: Millisecond-precision synchronization for moves and game states.
- **In-Game Executive Chat**: 
  - Real-time message exchange during matches.
  - Notification badges for unread messages.
  - Message history persistence.
- **Player Profiles & Identity**:
  - **Elo Rating System**: Dynamic rating updates based on match outcomes.
  - **Rank Progression**: Titles from **Novice** to **Dynamo Legend** based on performance.
  - **Digital ID Card**: A premium "Executive Card" UI showcasing player stats and rank.
  - **Activity Log**: Detailed match history with summaries (opponent, result, method, date).

## 🎨 Design & Visual Experience (Executive Minimalist)
The app features a state-of-the-art design language focused on luxury and clarity.
- **Premium Palette**: Deep charcoal and black backgrounds (`#0A0E0A`) accented with high-contrast **Executive Gold** (`#D4AF37`).
- **Dynamic Backgrounds**: Fluid, animated radial gradients and "Aura" glow effects that respond to UI states.
- **Glassmorphism**: Translucent panels and blurred overlays for a modern, high-end feel.
- **High-Fidelity Assets**: Custom-designed piece sets and board textures optimized for 10x10 layouts.
- **In-Game HUD (Heads-Up Display)**:
  - **Move History**: Scrollable log of all algebraic notations.
  - **Material Tracker**: Real-time count of captured pieces.
  - **Strategic Advantage**: Visual indicator showing which player leads in material value.
  - **Precision Clocks**: Tournament-grade timers supporting Bullet, Blitz, and Rapid controls.

## 🔔 Notifications & Feedback
- **Cross-Platform Alerts**: Support for Browser notifications (Web) and Push notifications (Mobile).
- **Challenge Alerts**: Real-time popups and audio cues when receiving a game invitation.
- **Soundscape**: Custom audio feedback for moves, captures, checkmates, and game alerts.

## 🛠️ Customization & Settings
Users can personalize their "Grandmaster" experience:
- **Board Themes**: Selection of premium visual styles for the grid.
- **Strategic Hints**: Toggleable indicators for legal moves and captures.
- **Coordinate System**: Toggle for board rank and file labels.
- **Move Highlighting**: Visual indicators for the last move made.
- **Automation**: Toggle for automatic pawn promotion to Queen.

## 🚀 Technical Architecture
- **Framework**: Flutter (Dart) for high-performance cross-platform execution.
- **Backend**: Firebase Realtime Database, Cloud Firestore, and Cloud Messaging.
- **Engine Logic**: 
  - `RulesEngine`: Custom 10x10 move validation.
  - `AIEngine`: Optimized search algorithms for variant play.
  - `FenConverter`: 10x10 FEN string support for state persistence.

---
*Document Version: 1.1 | May 7, 2026*
