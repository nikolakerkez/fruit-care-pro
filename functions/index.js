const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// 🔥 NOVA HTTP FUNKCIJA (onRequest)
exports.adminResetPasswordHttp = functions.https.onRequest(async (req, res) => {
  // CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  // Handle preflight
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  console.log("═══════════════════════════════════════");
  console.log("📞 adminResetPasswordHttp called");
  
  try {
    // 1. Check Authorization header
    const authHeader = req.headers.authorization;
    console.log("🔍 Auth header:", authHeader ? "EXISTS" : "MISSING");
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      console.log("❌ No token");
      return res.status(401).json({error: "No token"});
    }

    // 2. Extract token
    const idToken = authHeader.split('Bearer ')[1];
    console.log("🔍 Token length:", idToken.length);

    // 3. Verify token
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    console.log("✅ Token verified - UID:", decodedToken.uid);

    const adminUid = decodedToken.uid;

    // 4. Check if admin
    const adminUser = await admin.firestore()
      .collection("users")
      .doc(adminUid)
      .get();

    if (!adminUser.exists) {
      console.log("❌ User not found");
      return res.status(404).json({error: "User not found"});
    }

    const userData = adminUser.data();
    console.log("🔍 isAdmin:", userData.isAdmin);

    if (!userData.isAdmin) {
      console.log("❌ Not admin");
      return res.status(403).json({error: "Not admin"});
    }

    console.log("✅ User is admin");

    // 5. Get parameters
    const {userId, newPassword} = req.body;
    console.log("🔍 Target userId:", userId);
    console.log("🔍 Password length:", newPassword?.length);

    if (!userId || !newPassword) {
      console.log("❌ Missing params");
      return res.status(400).json({error: "Missing userId or newPassword"});
    }

    if (newPassword.length < 6) {
      console.log("❌ Password too short");
      return res.status(400).json({error: "Password must be 6+ chars"});
    }

    // 6. Reset password
    await admin.auth().updateUser(userId, {password: newPassword});
    console.log("✅ Password updated in Auth");

    // 7. Update Firestore
    await admin.firestore().collection("users").doc(userId).update({
      isPasswordChangeNeeded: true,
      passwordChangedAt: admin.firestore.FieldValue.serverTimestamp(),
      passwordChangedBy: adminUid,
    });

    console.log("✅ Firestore updated");
    console.log("═══════════════════════════════════════");

    return res.status(200).json({
      success: true,
      message: "Lozinka uspešno promenjena",
    });

  } catch (error) {
    console.error("❌ Error:", error.message);
    console.log("═══════════════════════════════════════");
    return res.status(500).json({error: error.message});
  }
});

exports.adminResetPassword = functions.https.onCall(async (data, context) => {
    // 🔥 DEBUG: Isprintaj sve što dobiješ
    console.log("📞 adminResetPassword called");
    console.log("🔍 context.auth:", context.auth);
    console.log("🔍 context.auth.uid:", context.auth?.uid);
    console.log("🔍 data:", data);
  
    // Proveri da li je admin
    if (!context.auth) {
      console.log("❌ context.auth is NULL - User not authenticated");
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Morate biti prijavljeni",
      );
    }
  
    const adminUid = context.auth.uid;
    console.log("✅ User authenticated:", adminUid);
  
    const adminUser = await admin.firestore()
        .collection("users").doc(adminUid).get();
  
    console.log("🔍 Admin user exists:", adminUser.exists);
    console.log("🔍 Admin user data:", adminUser.data());
  
    if (!adminUser.exists || !adminUser.data().isAdmin) {
      console.log("❌ User is not admin");
      throw new functions.https.HttpsError(
        "permission-denied",
        "Samo admin može resetovati lozinku",
      );
    }
  
    console.log("✅ User is admin, proceeding...");
  
    const {userId, newPassword} = data;
  
    if (!userId || !newPassword) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "userId i newPassword su obavezni",
      );
    }
  
    if (newPassword.length < 6) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Lozinka mora imati minimum 6 karaktera",
      );
    }
  
    try {
      // Reset password
      await admin.auth().updateUser(userId, {
        password: newPassword,
      });
  
      console.log("✅ Password updated in Auth");
  
      // Označi da korisnik mora da promeni lozinku
      await admin.firestore().collection("users").doc(userId).update({
        isPasswordChangeNeeded: true,
        passwordChangedAt: admin.firestore.FieldValue.serverTimestamp(),
        passwordChangedBy: adminUid,
      });
  
      console.log("✅ User document updated in Firestore");
  
      return {success: true, message: "Lozinka uspešno promenjena"};
    } catch (error) {
      console.error("❌ Error resetting password:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Greška pri resetovanju lozinke: " + error.message,
      );
    }
  });

  // 🔥 SUPER DETALJNI TEST
exports.testAuth = functions.https.onCall(async (data, context) => {
  console.log("═══════════════════════════════════════");
  console.log("📞 testAuth called");
  console.log("🔍 context.auth:", context.auth);
  console.log("🔍 context.auth exists:", !!context.auth);
  console.log("🔍 context.auth type:", typeof context.auth);
  
  if (context.rawRequest && context.rawRequest.headers) {
    console.log("🔍 Authorization header:", 
      context.rawRequest.headers.authorization ? "EXISTS" : "MISSING");
    
    if (context.rawRequest.headers.authorization) {
      const auth = context.rawRequest.headers.authorization;
      console.log("🔍 Auth header (first 100):", auth.substring(0, 100));
    }
  }
  
  console.log("═══════════════════════════════════════");
  
  if (!context.auth) {
    return {
      success: false,
      message: "Not authenticated",
      debug: {
        contextKeys: Object.keys(context),
        authType: typeof context.auth,
      },
    };
  }
  
  return {
    success: true,
    uid: context.auth.uid,
    email: context.auth.token.email || "no email",
  };
});