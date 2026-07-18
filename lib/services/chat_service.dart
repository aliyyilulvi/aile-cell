import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String myUid = FirebaseAuth.instance.currentUser!.uid;

  /// İki kullanıcı arasındaki sohbet için sabit/deterministik bir ID üretir.
  /// Böylece "chats/{chatId}" her zaman aynı iki kişi için aynı belgeye işaret eder.
  String chatIdFor(String otherUid) {
    final ids = [myUid, otherUid]..sort();
    return ids.join('_');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> myChatsStream() {
    return _db
        .collection('chats')
        .where('participants', arrayContains: myUid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('sentAt', descending: false)
        .snapshots();
  }

  Future<void> sendMessage({
    required String otherUid,
    required String text,
  }) async {
    final chatId = chatIdFor(otherUid);
    final chatRef = _db.collection('chats').doc(chatId);
    await chatRef.set({
      'participants': [myUid, otherUid],
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await chatRef.collection('messages').add({
      'senderId': myUid,
      'text': text,
      'sentAt': FieldValue.serverTimestamp(),
    });
  }

  /// Kullanıcı adına göre arama yaparak kişi ekleme.
  Future<Map<String, dynamic>?> findUserByUsername(String username) async {
    final query = await _db
        .collection('users')
        .where('username', isEqualTo: username.trim().toLowerCase())
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    final data = query.docs.first.data();
    // uid alanı belgede yoksa, belge id'sini uid olarak ekleyelim.
    data['uid'] ??= query.docs.first.id;
    return data;
  }

  /// Kişiyi tam bir "rehber kaydı" gibi ekler: isim, kullanıcı adı ve UID
  /// doğrudan kişinin kendi kaydının içine gömülür. Böylece daha sonra
  /// listelerken tekrar tekrar `getUser()` ile Firestore'a gitmeye gerek kalmaz.
  /// İki taraf da birbirini karşılıklı olarak rehberine ekler ki her iki
  /// kullanıcı da sohbeti kendi kişi listesinde görsün.
  Future<void> addContact(String otherUid, {String? otherDisplayName, String? otherUsername}) async {
    // Eğer isim/kullanıcı adı verilmediyse, Firestore'dan çekelim.
    String displayName = otherDisplayName ?? '';
    String username = otherUsername ?? '';
    if (displayName.isEmpty || username.isEmpty) {
      final otherDoc = await _db.collection('users').doc(otherUid).get();
      final data = otherDoc.data();
      displayName = data?['displayName'] ?? displayName;
      username = data?['username'] ?? username;
    }

    // Kendi rehberime ekle.
    await _db.collection('users').doc(myUid).collection('contacts').doc(otherUid).set({
      'uid': otherUid,
      'displayName': displayName,
      'username': username,
      'addedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Karşılıklı olsun diye, karşı tarafın rehberine de kendimi ekleyelim.
    final myDoc = await _db.collection('users').doc(myUid).get();
    final myData = myDoc.data();
    await _db.collection('users').doc(otherUid).collection('contacts').doc(myUid).set({
      'uid': myUid,
      'displayName': myData?['displayName'] ?? '',
      'username': myData?['username'] ?? '',
      'addedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> myContactsStream() {
    return _db
        .collection('users')
        .doc(myUid)
        .collection('contacts')
        .orderBy('addedAt', descending: true)
        .snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUser(String uid) {
    return _db.collection('users').doc(uid).get();
  }
}
