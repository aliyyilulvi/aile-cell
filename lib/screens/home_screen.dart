import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../main.dart' show kAccentPurple;
import 'chat_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();
    final myUid = chatService.myUid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aile Cell'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showAddContactDialog(context, chatService),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthService>().logout(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: chatService.myChatsStream(),
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
                future: chatService.getUser(otherUid),
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
