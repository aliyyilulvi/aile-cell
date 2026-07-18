import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';
import '../main.dart' show kAccentPurple, kLightPurple;
import 'call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String otherUid;
  final String otherName;

  const ChatScreen({super.key, required this.otherUid, required this.otherName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chatService = ChatService();
  final _textCtrl = TextEditingController();
  late final String _chatId;

  @override
  void initState() {
    super.initState();
    _chatId = _chatService.chatIdFor(widget.otherUid);
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    await _chatService.sendMessage(otherUid: widget.otherUid, text: text);
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _chatService.myUid;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherName),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            tooltip: 'Sesli ara',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CallScreen(
                  otherUid: widget.otherUid,
                  otherName: widget.otherName,
                  isCaller: true,
                  isVideoCall: false,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            tooltip: 'Görüntülü ara',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CallScreen(
                  otherUid: widget.otherUid,
                  otherName: widget.otherName,
                  isCaller: true,
                  isVideoCall: true,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _chatService.messagesStream(_chatId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  reverse: false,
                  padding: const EdgeInsets.all(8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final isMe = data['senderId'] == myUid;
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe ? kLightPurple : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(data['text'] ?? ''),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      decoration: InputDecoration(
                        hintText: 'Mesaj yazın...',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: kAccentPurple,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
