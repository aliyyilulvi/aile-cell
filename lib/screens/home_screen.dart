import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../main.dart' show kAccentPurple;
import 'chat_screen.dart';
import 'call_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _chatService = ChatService();
  final Set<String> _handledCallIds = {};
  bool _inCall = false;

  @override
  void initState() {
    super.initState();
    _listenIncomingCalls();
  }

  /// Firestore'daki "calls" koleksiyonunu dinler; bana ait (calleeId == myUid)
  /// ve durumu "ringing" olan yeni bir kayıt görürse, otomatik olarak
  /// CallScreen'i (isCaller: false) açar.
  void _listenIncomingCalls() {
    final myUid = _chatService.myUid;
    FirebaseFirestore.instance
        .collection('calls')
        .where('calleeId', isEqualTo: myUid)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((snapshot) async {
      for (var change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final doc = change.doc;
        final callId = doc.id;
        if (_handledCallIds.contains(callId)) continue;
        if (_inCall) continue; // zaten bir görüşmedeyiz, ikinci aramayı yoksay
        _handledCallIds.add(callId);

        final data = doc.data();
        if (data == null) continue;
        final callerId = data['callerId'] as String?;
        final isVideo = data['isVideo'] == true;
        if (callerId == null) continue;

        final callerDoc = await _chatService.getUser(callerId);
        final callerName = callerDoc.data()?['displayName'] ?? 'Bilinmeyen';

        if (!mounted) return;
        _inCall = true;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CallScreen(
              otherUid: callerId,
              otherName: callerName,
              isCaller: false,
              isVideoCall: isVideo,
              incomingCallId: callId,
            ),
          ),
        );
        _inCall = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _chatService.myUid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aile Cell'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showAddContactDialog(context, _chatService),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthService>().logout(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _chatService.myChatsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Henüz sohbet yok.\nSağ üstten kişi ekleyin.', textAlign: TextAlign.center));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final participants = List<String>.from(data['participants']);
              final otherUid = participants.firstWhere((id) => id != myUid);

              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: _chatService.getUser(otherUid),
                builder: (context, userSnap) {
                  final otherName = userSnap.data?.data()?['displayName'] ?? '...';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: kAccentPurple,
                      child: Text(otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text(otherName),
                    subtitle: Text(
                      data['lastMessage'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(otherUid: otherUid, otherName: otherName),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showAddContactDialog(BuildContext context, ChatService chatService) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kişi Ekle'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Kullanıcı adı'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          TextButton(
            onPressed: () async {
              final user = await chatService.findUserByUsername(controller.text);
              if (user == null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kullanıcı bulunamadı.')),
                  );
                }
                return;
              }
              await chatService.addContact(user['uid']);
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(otherUid: user['uid'], otherName: user['displayName']),
                  ),
                );
              }
            },
            child: const Text('Ekle ve Sohbet Et'),
          ),
        ],
      ),
    );
  }
}
