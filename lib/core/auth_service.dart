import 'package:firebase_auth/firebase_auth.dart';
import 'online_service.dart';

class AuthService {
  // Use a getter for _auth to ensure we don't access the instance until needed
  FirebaseAuth get _auth => FirebaseAuth.instance;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Current user
  User? get currentUser => _auth.currentUser;

  // Sign In
  Future<User?> signIn(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'An unknown error occurred';
    } catch (e) {
      throw 'An unknown error occurred';
    }
  }

  // Sign Up with unique username
  Future<User?> signUp(String email, String password, String username) async {
    try {
      // STEP 1: Validate username format
      if (username.length < 3) {
        throw 'Username must be at least 3 characters';
      }
      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
        throw 'Username can only contain letters, numbers, and underscores';
      }
      
      // STEP 2: Check if username is already taken
      final onlineService = OnlineService();
      final usernameExists = await onlineService.checkUsernameExists(username);
      if (usernameExists) {
        throw 'Username "$username" is already taken';
      }
      
      // STEP 3: Create Firebase Auth account
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // STEP 4: Update display name and create profile
      if (userCredential.user != null) {
        await userCredential.user!.updateDisplayName(username);
        await userCredential.user!.reload();
        
        // STEP 5: Reserve username in database (for lookups)
        await onlineService.reserveUsername(
          username,
          userCredential.user!.uid,
        );
        
        // STEP 6: Create user profile with username
        await onlineService.updateUserProfile(
          userCredential.user!.uid,
          username,
          email,
        );
      }
      
      return _auth.currentUser;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'An unknown error occurred';
    } catch (e) {
      throw e.toString();
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }
  
  // Reset Password
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'An unknown error occurred';
    }
  }
}
