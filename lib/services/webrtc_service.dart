import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Sesli arama mantığı: WebRTC medya akışını doğrudan P2P (kişiler arası)
/// olarak internet üzerinden taşır; Firestore burada sadece "sinyalleşme"
/// (offer/answer/ICE aday bilgisi) için bir posta kutusu gibi kullanılır.
/// Gerçek ses trafiği Firestore'dan GEÇMEZ, doğrudan iki cihaz arasında
/// (veya TURN sunucusu röle ederek) akar.
class WebRTCService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String myUid = FirebaseAuth.instance.currentUser!.uid;

  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;

  // Ücretsiz STUN sunucuları (Google'ın herkese açık STUN sunucuları).
  // TURN için "Backend Kurulumu" bölümündeki açıklamaya bakın.
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      // Örnek ücretsiz TURN (kendi sunucunuzu kurmanız önerilir, bkz. açıklama):
      // {
      //   'urls': 'turn:relay1.expressturn.com:3480',
      //   'username': 'YOUR_TURN_USERNAME',
      //   'credential': 'YOUR_TURN_PASSWORD',
      // },
    ],
  };

  Future<void> initLocalStream({bool video = false}) async {
    localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': video
          ? {
              'facingMode': 'user',
              'width': {'ideal': 640},
              'height': {'ideal': 480},
            }
          : false,
    });
  }

  Future<String> startCall(
    String otherUid,
    Function(MediaStream) onRemoteStream, {
    bool isVideo = false,
  }) async {
    final ids = [myUid, otherUid]..sort();
    final callId = ids.join('_');
    final callDoc = _db.collection('calls').doc(callId);
    final offerCandidates = callDoc.collection('offerCandidates');
    final answerCandidates = callDoc.collection('answerCandidates');

    peerConnection = await createPeerConnection(_iceServers);

    localStream!.getTracks().forEach((track) {
      peerConnection!.addTrack(track, localStream!);
    });

    peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams[0];
        onRemoteStream(remoteStream!);
      }
    };

    peerConnection!.onIceCandidate = (candidate) {
      offerCandidates.add(candidate.toMap());
    };

    final offerDescription = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offerDescription);

    await callDoc.set({
      'callerId': myUid,
      'calleeId': otherUid,
      'offer': {'sdp': offerDescription.sdp, 'type': offerDescription.type},
      'status': 'ringing',
      'isVideo': isVideo,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Karşı taraf cevap verince bağlantıyı tamamla.
    callDoc.snapshots().listen((snapshot) async {
      final data = snapshot.data();
      if (data != null &&
          data['answer'] != null &&
          peerConnection!.getRemoteDescription() == null) {
        final answer = RTCSessionDescription(
          data['answer']['sdp'],
          data['answer']['type'],
        );
        await peerConnection!.setRemoteDescription(answer);
      }
    });

    answerCandidates.snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;
          peerConnection!.addCandidate(RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          ));
        }
      }
    });

    return callId;
  }

  Future<void> answerCall(String callId, Function(MediaStream) onRemoteStream) async {
    final callDoc = _db.collection('calls').doc(callId);
    final offerCandidates = callDoc.collection('offerCandidates');
    final answerCandidates = callDoc.collection('answerCandidates');

    peerConnection = await createPeerConnection(_iceServers);

    localStream!.getTracks().forEach((track) {
      peerConnection!.addTrack(track, localStream!);
    });

    peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams[0];
        onRemoteStream(remoteStream!);
      }
    };

    peerConnection!.onIceCandidate = (candidate) {
      answerCandidates.add(candidate.toMap());
    };

    final callData = (await callDoc.get()).data()!;
    final offer = callData['offer'];
    await peerConnection!.setRemoteDescription(
      RTCSessionDescription(offer['sdp'], offer['type']),
    );

    final answerDescription = await peerConnection!.createAnswer();
    await peerConnection!.setLocalDescription(answerDescription);

    await callDoc.update({
      'answer': {'sdp': answerDescription.sdp, 'type': answerDescription.type},
      'status': 'connected',
    });

    offerCandidates.snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;
          peerConnection!.addCandidate(RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          ));
        }
      }
    });
  }

  /// Gelen aramanın görüntülü olup olmadığını (ve arayan bilgisini) öğrenmek için.
  Future<Map<String, dynamic>?> getCallInfo(String callId) async {
    final doc = await _db.collection('calls').doc(callId).get();
    return doc.data();
  }

  /// Kendi mikrofonunu aç/kapat (mute).
  void toggleMic(bool enabled) {
    localStream?.getAudioTracks().forEach((track) => track.enabled = enabled);
  }

  /// Kendi kamerasını aç/kapat.
  void toggleCamera(bool enabled) {
    localStream?.getVideoTracks().forEach((track) => track.enabled = enabled);
  }

  /// Ön/arka kamera arasında geçiş yapar (görüntülü arama sırasında).
  Future<void> switchCamera() async {
    final videoTracks = localStream?.getVideoTracks() ?? [];
    if (videoTracks.isNotEmpty) {
      await Helper.switchCamera(videoTracks.first);
    }
  }

  Future<void> hangUp(String callId) async {
    localStream?.getTracks().forEach((t) => t.stop());
    await peerConnection?.close();
    if (callId.isNotEmpty) {
      await _db.collection('calls').doc(callId).update({'status': 'ended'});
    }
  }
}
