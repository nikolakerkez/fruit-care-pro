const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onRequest, onCall, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

// Tvoje admin funkcije ostaju iste...
exports.adminResetPasswordHttp = onRequest(async (req, res) => {
  // ... tvoj postojeći kod ...
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  console.log("═══════════════════════════════════════");
  console.log("📞 adminResetPasswordHttp called");
  
  try {
    const authHeader = req.headers.authorization;
    console.log("🔍 Auth header:", authHeader ? "EXISTS" : "MISSING");
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      console.log("❌ No token");
      return res.status(401).json({error: "No token"});
    }

    const idToken = authHeader.split('Bearer ')[1];
    console.log("🔍 Token length:", idToken.length);

    const decodedToken = await admin.auth().verifyIdToken(idToken);
    console.log("✅ Token verified - UID:", decodedToken.uid);

    const adminUid = decodedToken.uid;

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

    await admin.auth().updateUser(userId, {password: newPassword});
    console.log("✅ Password updated in Auth");

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

exports.adminResetPassword = onCall(async (request) => {
    const data = request.data;
    const auth = request.auth;
    
    console.log("📞 adminResetPassword called");
    console.log("🔍 auth:", auth);
    console.log("🔍 data:", data);
  
    if (!auth) {
      console.log("❌ context.auth is NULL - User not authenticated");
      throw new HttpsError(
        "unauthenticated",
        "Morate biti prijavljeni",
      );
    }
  
    const adminUid = auth.uid;
    console.log("✅ User authenticated:", adminUid);
  
    const adminUser = await admin.firestore()
        .collection("users").doc(adminUid).get();
  
    console.log("🔍 Admin user exists:", adminUser.exists);
    console.log("🔍 Admin user data:", adminUser.data());
  
    if (!adminUser.exists || !adminUser.data().isAdmin) {
      console.log("❌ User is not admin");
      throw new HttpsError(
        "permission-denied",
        "Samo admin može resetovati lozinku",
      );
    }
  
    console.log("✅ User is admin, proceeding...");
  
    const {userId, newPassword} = data;
  
    if (!userId || !newPassword) {
      throw new HttpsError(
        "invalid-argument",
        "userId i newPassword su obavezni",
      );
    }
  
    if (newPassword.length < 6) {
      throw new HttpsError(
        "invalid-argument",
        "Lozinka mora imati minimum 6 karaktera",
      );
    }
  
    try {
      await admin.auth().updateUser(userId, {
        password: newPassword,
      });
  
      console.log("✅ Password updated in Auth");
  
      await admin.firestore().collection("users").doc(userId).update({
        isPasswordChangeNeeded: true,
        passwordChangedAt: admin.firestore.FieldValue.serverTimestamp(),
        passwordChangedBy: adminUid,
      });
  
      console.log("✅ User document updated in Firestore");
  
      return {success: true, message: "Lozinka uspešno promenjena"};
    } catch (error) {
      console.error("❌ Error resetting password:", error);
      throw new HttpsError(
        "internal",
        "Greška pri resetovanju lozinke: " + error.message,
      );
    }
  });

// 🔥 CHAT NOTIFICATION - v2 API bez Eventarc problema
exports.sendChatNotification = onDocumentCreated(
  {
    document: "chats/{chatId}/messages/{messageId}",
    region: "us-central1",
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("No data");
      return;
    }
    
    const message = snapshot.data();
    const chatId = event.params.chatId;
    const senderId = message.senderId;
    
    try {
      console.log('📩 New message in chat:', chatId);
      console.log('👤 Sender ID:', senderId);
      
      const chatDoc = await admin.firestore()
        .collection('chats')
        .doc(chatId)
        .get();
      
      if (!chatDoc.exists) {
        console.log('❌ Chat not found');
        return;
      }
      
      const chatData = chatDoc.data();
      const memberIds = chatData.memberIds || [];
      
      // 🔍 DEBUG
      console.log('👥 memberIds iz chata:', JSON.stringify(memberIds));
      console.log('📊 Broj članova:', memberIds.length);
      
      const senderDoc = await admin.firestore()
        .collection('users')
        .doc(senderId)
        .get();
      
      const senderName = senderDoc.data()?.name || 
                         senderDoc.data()?.displayName || 
                         'Neko';
      
      const recipientIds = memberIds.filter(id => id !== senderId);
      
      // 🔍 DEBUG
      console.log('📬 recipientIds:', JSON.stringify(recipientIds));
      
      if (recipientIds.length === 0) {
        console.log('⚠️ No recipients found');
        return;
      }
      
      const tokenPromises = recipientIds.map(async (recipientId) => {
        console.log('🔍 Tražim token za:', recipientId);
        
        const userDoc = await admin.firestore()
          .collection('users')
          .doc(recipientId)
          .get();
        
        // 🔍 DEBUG
        console.log('📄 User postoji:', userDoc.exists);
        console.log('📄 User data keys:', userDoc.exists ? Object.keys(userDoc.data()) : 'N/A');
        
        const token = userDoc.data()?.fcmToken;
        
        // 🔍 DEBUG
        console.log('🔑 Token za', recipientId, ':', token ? `EXISTS (${token.substring(0, 20)}...)` : 'NULL ❌');
        
        return { recipientId, token };
      });
      
      const tokenData = await Promise.all(tokenPromises);
      const validTokens = tokenData.filter(t => t.token != null);
      
      console.log('✅ Valid tokens:', validTokens.length);
      
      if (validTokens.length === 0) {
        console.log('⚠️ No valid FCM tokens');
        return;
      }
      
      let messageText = message.message || '';
      if (message.imageUrl && !messageText) {
        messageText = '📷 Slika';
      }
      
      const notifications = validTokens.map(({ recipientId, token }) => {
        return admin.messaging().send({
          token: token,
          notification: {
            title: senderName,
            body: messageText,
          },
          data: {
            chatId: chatId,
            senderId: senderId,
            type: 'chat_message',
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
                'content-available': 1,
              },
            },
          },
          android: {
            priority: 'high',
            notification: {
              sound: 'default',
              channelId: 'chat_messages',
            },
          },
        });
      });
      
      const results = await Promise.allSettled(notifications);
      
      let successCount = 0;
      let failedTokens = [];
      
      results.forEach((result, index) => {
        if (result.status === 'fulfilled') {
          successCount++;
          console.log('✅ Notification sent to:', validTokens[index].recipientId);
        } else {
          console.error('❌ Failed:', validTokens[index].recipientId, result.reason?.message);
          
          const error = result.reason;
          if (error.code === 'messaging/invalid-registration-token' ||
              error.code === 'messaging/registration-token-not-registered') {
            failedTokens.push(validTokens[index]);
          }
        }
      });
      
      console.log(`✅ Sent ${successCount}/${validTokens.length} notifications`);
      
      if (failedTokens.length > 0) {
        const cleanup = failedTokens.map(({ recipientId }) => {
          return admin.firestore()
            .collection('users')
            .doc(recipientId)
            .update({ 
              fcmToken: admin.firestore.FieldValue.delete() 
            });
        });
        
        await Promise.all(cleanup);
        console.log(`🧹 Cleaned up ${failedTokens.length} invalid tokens`);
      }
    } catch (error) {
      console.error('❌ Error:', error);
    }
  }
);