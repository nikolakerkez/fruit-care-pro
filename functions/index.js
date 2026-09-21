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

// Kreira novi korisnički nalog (Auth + Firestore) preko Admin SDK-a, tako
// da ostane server-side i NE menja Auth sesiju admina koji poziva (za
// razliku od starog client-side _auth.createUserWithEmailAndPassword, koje
// je automatski logovalo admina kao novokreiranog korisnika).
exports.adminCreateUserHttp = onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  console.log("═══════════════════════════════════════");
  console.log("📞 adminCreateUserHttp called");

  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return res.status(401).json({error: "No token"});
    }

    const idToken = authHeader.split("Bearer ")[1];
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const adminUid = decodedToken.uid;

    const adminUserDoc = await admin.firestore()
        .collection("users")
        .doc(adminUid)
        .get();

    if (!adminUserDoc.exists || !adminUserDoc.data().isAdmin) {
      console.log("❌ Not admin");
      return res.status(403).json({error: "Not admin"});
    }

    const {name, email, password, city, phone, fruitTypes} = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({error: "Missing name, email or password"});
    }

    if (password.length < 6) {
      return res.status(400).json({error: "Password must be 6+ chars"});
    }

    const safeFruitTypes = Array.isArray(fruitTypes) ? fruitTypes : [];

    // Proveri jedinstvenost email-a (isto kao stari client-side kod)
    const existing = await admin.firestore()
        .collection("users")
        .where("email", "==", email)
        .limit(1)
        .get();

    if (!existing.empty) {
      return res.status(200).json({success: false, notUniqueUsername: true});
    }

    let newUserId;
    try {
      const newAuthUser = await admin.auth().createUser({email, password});
      newUserId = newAuthUser.uid;
    } catch (e) {
      console.error("❌ Auth createUser error:", e.message);
      if (e.code === "auth/email-already-exists") {
        return res.status(200).json({success: false, notUniqueUsername: true});
      }
      return res.status(500).json({error: e.message});
    }

    const chatId = newUserId.localeCompare(adminUid) < 0 ?
      `chat_${newUserId}_${adminUid}` :
      `chat_${adminUid}_${newUserId}`;

    const db = admin.firestore();
    const batch = db.batch();

    batch.set(db.collection("users").doc(newUserId), {
      email: email,
      name: name,
      isActive: false,
      uid: newUserId,
      city: city || "",
      phone: phone || "",
      isPasswordChangeNeeded: true,
    });

    for (const ft of safeFruitTypes) {
      const userFruitTypeRef = db.collection("user_2_fruittypes").doc();
      batch.set(userFruitTypeRef, {
        userId: newUserId,
        fruitId: ft.fruitTypeId,
        numberOfTrees: ft.numberOfTrees,
      });

      const fruitTypeChatRef = db.collection("chats").doc(ft.fruitTypeId);
      batch.update(fruitTypeChatRef, {
        memberIds: admin.firestore.FieldValue.arrayUnion(newUserId),
      });

      const fruitTypeChatMemberRef = fruitTypeChatRef
          .collection("members").doc(newUserId);
      batch.set(fruitTypeChatMemberRef, {
        userId: newUserId,
        lastMessage: {
          message: "-",
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          read: false,
        },
        memberSince: admin.firestore.FieldValue.serverTimestamp(),
        messagesVisibleFrom: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    }

    const privateChatRef = db.collection("chats").doc(chatId);
    batch.set(privateChatRef, {
      type: "private",
      name: "Private chat",
      lastMessage: {
        text: "",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        senderId: "",
        readBy: {},
      },
      lastMessageTimestamp: admin.firestore.FieldValue.serverTimestamp(),
      members: [],
      memberIds: [newUserId, adminUid],
    });

    for (const memberId of [adminUid, newUserId]) {
      const memberRef = privateChatRef.collection("members").doc(memberId);
      batch.set(memberRef, {
        userId: memberId,
        lastMessage: {
          message: "-",
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          read: false,
        },
        memberSince: admin.firestore.FieldValue.serverTimestamp(),
        messagesVisibleFrom: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    }

    await batch.commit();

    console.log("✅ Created user:", newUserId);
    console.log("═══════════════════════════════════════");

    return res.status(200).json({success: true, userId: newUserId});
  } catch (error) {
    console.error("❌ Error:", error.message);
    console.log("═══════════════════════════════════════");
    return res.status(500).json({error: error.message});
  }
});

// Korisnik briše SOPSTVENI nalog. Server-side (Admin SDK) da se rekurzivno
// obrišu privatni chat sa svim porukama i slikama iz Storage-a, što klijent
// ne može (Firestore ne briše podkolekcije automatski). Klijent pre poziva
// radi re-autentifikaciju lozinkom.
exports.deleteMyAccountHttp = onRequest({timeoutSeconds: 300}, async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    return res.status(405).json({error: "Method not allowed"});
  }

  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return res.status(401).json({error: "No token"});
    }

    const decodedToken = await admin.auth()
        .verifyIdToken(authHeader.split("Bearer ")[1]);
    const uid = decodedToken.uid;

    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();

    if (userSnap.exists && userSnap.data().isAdmin) {
      return res.status(403).json({error: "Admin account cannot be deleted"});
    }

    const bucket = admin.storage().bucket();
    const deleteFile = async (path) => {
      if (!path) return;
      try {
        await bucket.file(path).delete({ignoreNotFound: true});
      } catch (e) {
        console.warn("⚠️ Storage delete failed:", path, e.message);
      }
    };

    const removeFromGroupChat = async (chatRef) => {
      await chatRef.update({
        memberIds: admin.firestore.FieldValue.arrayRemove(uid),
      });
      await chatRef.collection("members").doc(uid).delete();
    };

    // 1. Profilne slike
    if (userSnap.exists) {
      await deleteFile(userSnap.data().imagePath);
      await deleteFile(userSnap.data().thumbPath);
    }

    // 2. Chatovi: grupni → samo ukloni korisnika; privatni → obriši ceo chat
    //    (poruke + slike)
    const chats = await db.collection("chats")
        .where("memberIds", "array-contains", uid)
        .get();

    for (const chatDoc of chats.docs) {
      const data = chatDoc.data();
      const isGroup = data.type === "group" || data.isGroup === true;

      if (isGroup) {
        await removeFromGroupChat(chatDoc.ref);
      } else {
        const messages = await chatDoc.ref.collection("messages").get();
        await Promise.all(messages.docs.flatMap((m) => [
          deleteFile(m.data().imagePath),
          deleteFile(m.data().thumbPath),
        ]));
        await db.recursiveDelete(chatDoc.ref);
      }
    }

    // 3. Veze sa voćnim vrstama (+ grupni chat, ako memberIds nije bio u sinhronizaciji)
    const links = await db.collection("user_2_fruittypes")
        .where("userId", "==", uid)
        .get();

    for (const link of links.docs) {
      const fruitId = link.data().fruitId;
      if (fruitId) {
        const groupChatRef = db.collection("chats").doc(fruitId);
        if ((await groupChatRef.get()).exists) {
          await removeFromGroupChat(groupChatRef);
        }
      }
      await link.ref.delete();
    }

    // 4. Profil i Auth nalog
    await userRef.delete();

    try {
      await admin.auth().deleteUser(uid);
    } catch (e) {
      if (e.code !== "auth/user-not-found") throw e;
    }

    console.log("✅ Deleted account:", uid);
    return res.status(200).json({success: true});
  } catch (error) {
    console.error("❌ deleteMyAccountHttp error:", error.message);
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
    const messageId = event.params.messageId;
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

      let messageText = message.message || '';
      if (!messageText) {
        // imageUrl je null pri kreiranju (upload još traje), ali message je prazan → slika
        messageText = '📷 Slika';
      }

      const isGroupChat = chatData.type === 'group';
      const notificationTitle = isGroupChat ? (chatData.name || senderName) : senderName;
      const notificationBody = isGroupChat ? `${senderName}: ${messageText}` : messageText;

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
        const activeChatId = userDoc.data()?.activeChatId;

        // 🔍 DEBUG
        console.log('🔑 Token za', recipientId, ':', token ? `EXISTS (${token.substring(0, 20)}...)` : 'NULL ❌');

        // Preskoči ako je korisnik već u ovom chatu
        if (activeChatId === chatId) {
          console.log(`⏭️ Skipping ${recipientId} - already in chat`);
          return { recipientId, token: null };
        }

        return { recipientId, token };
      });
      
      const tokenData = await Promise.all(tokenPromises);
      const validTokens = tokenData.filter(t => t.token != null);
      
      console.log('✅ Valid tokens:', validTokens.length);
      
      if (validTokens.length === 0) {
        console.log('⚠️ No valid FCM tokens');
        return;
      }
      
      const notifications = validTokens.map(async ({ recipientId, token }) => {
        // Inkrementiraj badge counter za ovog korisnika i uzmi novi broj
        const userRef = admin.firestore().collection('users').doc(recipientId);
        const newBadgeCount = await admin.firestore().runTransaction(async (t) => {
          const userDoc = await t.get(userRef);
          const current = userDoc.data()?.badgeCount || 0;
          const next = current + 1;
          t.update(userRef, {
            badgeCount: next,
            [`chatBadgeCounts.${chatId}`]: admin.firestore.FieldValue.increment(1),
          });
          return next;
        });

        return admin.messaging().send({
          token: token,
          // Nema top-level "notification" polja - na Androidu se poruka tretira
          // kao data-only i uvek stiže u onBackgroundMessage/onMessage handler,
          // gde app sam pravi grupisanu notifikaciju (kao WhatsApp).
          data: {
            chatId: chatId,
            senderId: senderId,
            messageId: messageId,
            type: 'chat_message',
            title: notificationTitle,
            body: notificationBody,
          },
          apns: {
            payload: {
              aps: {
                // iOS i dalje prikazuje native alert (iz aps.alert), i grupiše
                // ga u Notification Center-u po thread-id (= chatId).
                alert: {
                  title: notificationTitle,
                  body: notificationBody,
                },
                sound: 'default',
                badge: newBadgeCount,
                'thread-id': chatId,
              },
            },
          },
          android: {
            priority: 'high',
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