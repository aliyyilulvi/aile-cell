import 'package:flutter/material.dart';
import '../services/webrtc_service.dart';
import '../main.dart' show kPrimaryPurple, kAccentPurple;
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Sesli VEYA görüntülü arama ekranı.
/// - `isCaller: true` ise bu ekran açılır açılmaz araması başlatır.
/// - `isCaller: false` ise `incomingCallId` ile gelen bir aramayı yanıtlar.
/// - `isVideoCall: true` ise kamera da açılır ve iki video görüntüsü gösterilir.
class CallScreen extends StatefulWidget {
  final String otherUid;
  final String otherName;
  final bool isCaller;
  final bool isVideoCall;
  final String? incomingCallId;

  const CallScreen({
    super.key,
    required this.otherUid,
    required this.otherName,
    required this.isCaller,
    this.isVideoCall = false,
    this.incomingCallId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _webrtc = WebRTCService();
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  String _status = 'Bağlanıyor...';
  String _callId = '';
  bool _micOn = true;
  bool _cameraOn = true;
  bool _remoteVideoReady = false;
  late bool _isVideoCall;

  @override
  void initState() {
    super.initState();
    _isVideoCall = widget.isVideoCall;
    _init();
  }

  Future<void> _init() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    await _startCallFlow();
  }

  Future<void> _startCallFlow() async {
    if (widget.isCaller) {
      await _webrtc.initLocalStream(video: _isVideoCall);
      _localRenderer.srcObject = _webrtc.localStream;
      setState(() {});

      _callId = await _webrtc.startCall(
        widget.otherUid,
        (remoteStream) {
          _remoteRenderer.srcObject = remoteStream;
          setState(() {
            _status = 'Görüşme devam ediyor';
            _remoteVideoReady = true;
          });
        },
        isVideo: _isVideoCall,
      );
      setState(() => _status = 'Çalıyor...');
    } else if (widget.incomingCallId != null) {
      _callId = widget.incomingCallId!;
      // Gelen aramanın görüntülü olup olmadığını kontrol et.
      final info = await _webrtc.getCallInfo(_callId);
      _isVideoCall = info?['isVideo'] == true;

      await _webrtc.initLocalStream(video: _isVideoCall);
      _localRenderer.srcObject = _webrtc.localStream;
      setState(() {});

      await _webrtc.answerCall(_callId, (remoteStream) {
        _remoteRenderer.srcObject = remoteStream;
        setState(() {
          _status = 'Görüşme devam ediyor';
          _remoteVideoReady = true;
        });
      });
    }
  }

  void _toggleMic() {
    _micOn = !_micOn;
    _webrtc.toggleMic(_micOn);
    setState(() {});
  }

  void _toggleCamera() {
    _cameraOn = !_cameraOn;
    _webrtc.toggleCamera(_cameraOn);
    setState(() {});
  }

  void _switchCamera() => _webrtc.switchCamera();

  Future<void> _endCall() async {
    await _webrtc.hangUp(_callId);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _webrtc.localStream?.getTracks().forEach((t) => t.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isVideoCall) {
      return _buildVideoCallUI();
    }
    return _buildAudioCallUI();
  }

  // ---------- SESLİ ARAMA ARAYÜZÜ ----------
  Widget _buildAudioCallUI() {
    return Scaffold(
      backgroundColor: kPrimaryPurple,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white24,
              child: Text(
                widget.otherName.isNotEmpty ? widget.otherName[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 48, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            Text(widget.otherName, style: const TextStyle(color: Colors.white, fontSize: 24)),
            const SizedBox(height: 8),
            Text(_status, style: const TextStyle(color: Colors.white70)),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _roundButton(
                    icon: _micOn ? Icons.mic : Icons.mic_off,
                    onTap: _toggleMic,
                    background: Colors.white24,
                  ),
                  const SizedBox(width: 28),
                  _roundButton(
                    icon: Icons.call_end,
                    onTap: _endCall,
                    background: Colors.red,
                    size: 68,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ---------- GÖRÜNTÜLÜ ARAMA ARAYÜZÜ ----------
  Widget _buildVideoCallUI() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Karşı tarafın görüntüsü (tam ekran)
          Positioned.fill(
            child: _remoteVideoReady
                ? RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                : Container(
                    color: kPrimaryPurple,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white24,
                            child: Text(
                              widget.otherName.isNotEmpty ? widget.otherName[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 40, color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(widget.otherName, style: const TextStyle(color: Colors.white, fontSize: 22)),
                          const SizedBox(height: 6),
                          Text(_status, style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
          ),

          // Kendi görüntümüz (küçük, sağ üst köşe)
          Positioned(
            top: 40,
            right: 16,
            child: Container(
              width: 110,
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kAccentPurple, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: _cameraOn
                  ? RTCVideoView(_localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                  : Container(color: Colors.grey[900], child: const Icon(Icons.videocam_off, color: Colors.white54)),
            ),
          ),

          // Üst bar: isim ve durum
          Positioned(
            top: 44,
            left: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.otherName,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text(_status, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),

          // Alt kontrol çubuğu
          Positioned(
            bottom: 36,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _roundButton(
                  icon: _micOn ? Icons.mic : Icons.mic_off,
                  onTap: _toggleMic,
                  background: Colors.white24,
                ),
                const SizedBox(width: 20),
                _roundButton(
                  icon: _cameraOn ? Icons.videocam : Icons.videocam_off,
                  onTap: _toggleCamera,
                  background: Colors.white24,
                ),
                const SizedBox(width: 20),
                _roundButton(
                  icon: Icons.cameraswitch,
                  onTap: _switchCamera,
                  background: Colors.white24,
                ),
                const SizedBox(width: 20),
                _roundButton(
                  icon: Icons.call_end,
                  onTap: _endCall,
                  background: Colors.red,
                  size: 62,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color background,
    double size = 54,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: size * 0.45),
      ),
    );
  }
}
