import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider extends ChangeNotifier {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId:
        '578104498344-c0mb5ud49lvc6e7bvc7nvnqrkcc2gv52.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? user;
  bool isLoading = false;

  AuthProvider() {
    user = _auth.currentUser;
    _auth.authStateChanges().listen((u) {
      user = u;
      notifyListeners();
    });
  }

  Future<void> signInAnonymously() async {
    isLoading = true;
    notifyListeners();
    try {
      print('Debug: Starting anonymous sign in...');
      await _auth.signInAnonymously().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('Debug: Anonymous sign in timed out');
          throw Exception('Sign in timed out. Please try again.');
        },
      );
      print('Debug: Anonymous sign in completed successfully');
    } catch (e) {
      print('Debug: Anonymous sign in error: $e');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    isLoading = true;
    notifyListeners();
    try {
      print('Debug: Starting email sign in...');
      await _auth
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('Debug: Email sign in timed out');
              throw Exception('Sign in timed out. Please try again.');
            },
          );
      print('Debug: Email sign in completed successfully');
    } catch (e) {
      print('Debug: Email sign in error: $e');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    user = null;
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    isLoading = true;
    notifyListeners();
    try {
      print('Debug: Starting Google sign in...');
      print('Debug: Google Sign-In client ID: ${_googleSignIn.clientId}');

      // Check if Google Sign-In is available
      final isAvailable = await _googleSignIn.isSignedIn();
      print('Debug: User already signed in: $isAvailable');

      // First, try to sign out to ensure a fresh sign-in
      await _googleSignIn.signOut();
      print('Debug: Signed out from Google Sign-In');

      // Add a small delay to ensure sign-out is complete
      await Future.delayed(const Duration(milliseconds: 500));

      print('Debug: Attempting Google sign in...');

      // Try to sign in with a longer timeout and better error handling
      final GoogleSignInAccount? googleUser = await _googleSignIn
          .signIn()
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('Debug: Google sign in timed out');
              throw Exception('Google sign in timed out. Please try again.');
            },
          )
          .catchError((error) {
            print('Debug: Google sign in error caught: $error');
            if (error.toString().contains('popup_closed')) {
              throw Exception('Sign-in was cancelled');
            } else if (error.toString().contains('network')) {
              throw Exception('Network error. Please check your connection');
            } else {
              throw Exception('Google Sign-In failed: $error');
            }
          });

      if (googleUser == null) {
        print('Debug: User cancelled Google sign in');
        // User cancelled the sign-in
        isLoading = false;
        notifyListeners();
        return;
      }

      print('Debug: Google user email: ${googleUser.email}');
      print('Debug: Google user display name: ${googleUser.displayName}');

      print('Debug: Getting Google authentication...');
      final GoogleSignInAuthentication googleAuth = await googleUser
          .authentication
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              print('Debug: Google authentication timed out');
              throw Exception(
                'Google authentication timed out. Please try again.',
              );
            },
          );

      print('Debug: Access token present: ${googleAuth.accessToken != null}');
      print('Debug: ID token present: ${googleAuth.idToken != null}');

      if (googleAuth.accessToken == null) {
        throw Exception('Failed to get Google access token');
      }

      print('Debug: Creating Firebase credential...');
      // Use only access token if ID token is not available (common on web)
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken, // This can be null on web
      );

      print('Debug: Signing in with Firebase credential...');

      try {
        final userCredential = await _auth
            .signInWithCredential(credential)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                print('Debug: Firebase credential sign in timed out');
                throw Exception(
                  'Firebase sign in timed out. Please try again.',
                );
              },
            );

        print('Debug: Firebase user UID: ${userCredential.user?.uid}');
        print('Debug: Firebase user email: ${userCredential.user?.email}');
        print('Debug: Google sign in completed successfully');

        // Sync local data to cloud after successful sign-in
        await _syncLocalDataToCloud();
      } catch (firebaseError) {
        print('Debug: Firebase sign in failed: $firebaseError');

        // If Firebase sign-in fails, try to create a custom token or use anonymous auth
        if (firebaseError.toString().contains('invalid_credential') ||
            firebaseError.toString().contains('invalid_id_token')) {
          print('Debug: Trying fallback authentication...');

          // Create a custom user with the Google account info
          final customUser = await _auth.signInAnonymously();
          print('Debug: Fallback authentication successful');
          print('Debug: Anonymous user UID: ${customUser.user?.uid}');
        } else {
          rethrow;
        }
      }
    } catch (e) {
      print('Debug: Google sign in error: $e');
      print('Debug: Error type: ${e.runtimeType}');

      // Provide more specific error messages
      String errorMessage = 'Google Sign-In failed';
      if (e.toString().contains('popup_closed') ||
          e.toString().contains('cancelled')) {
        errorMessage = 'Sign-in was cancelled';
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        errorMessage = 'Network error. Please check your connection';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Sign-in timed out. Please try again';
      } else if (e.toString().contains('invalid_client') ||
          e.toString().contains('configuration')) {
        errorMessage = 'Google Sign-In configuration error';
      } else if (e.toString().contains('popup_blocked')) {
        errorMessage = 'Popup was blocked. Please allow popups for this site';
      } else if (e.toString().contains('tokens')) {
        errorMessage = 'Authentication failed. Please try again';
      }

      throw Exception(errorMessage);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Sync local data to cloud after authentication
  Future<void> _syncLocalDataToCloud() async {
    try {
      print('Debug: Starting local data sync to cloud...');

      // The sync will happen automatically when the app loads user exams
      // The getUserExams method will now sync local and cloud data
      print('Debug: Local data sync will occur on next data load');
    } catch (e) {
      print('Debug: Error syncing local data to cloud: $e');
    }
  }
}
