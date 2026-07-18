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
    return query.docs.first.data();
  }

  Future<void> addContact(String otherUid) async {
    await _db.collection('users').doc(myUid).collection('contacts').doc(otherUid).set({
      'addedAt': FieldValue.serverTimestamp(),
    });
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
