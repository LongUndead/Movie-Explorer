import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class TrailerDialog extends StatefulWidget {
  final String youtubeUrl;
  const TrailerDialog({super.key, required this.youtubeUrl});

  @override
  State<TrailerDialog> createState() => _TrailerDialogState();
}

class _TrailerDialogState extends State<TrailerDialog> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    final videoId = YoutubePlayer.convertUrlToId(widget.youtubeUrl) ?? 'TcMBFSGVi1c'; 
    
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Dialog(
      backgroundColor: Colors.black, 
      elevation: 0,
      insetPadding: EdgeInsets.zero, 
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: isLandscape ? MediaQuery.of(context).size.height : null,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Center(
              child: YoutubePlayer(controller: _controller, showVideoProgressIndicator: true, progressIndicatorColor: Colors.red),
            ),
            SafeArea( 
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}