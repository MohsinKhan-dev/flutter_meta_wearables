import 'package:flutter/widgets.dart';

import '../models/models.dart';
import '../stream_session.dart';

class WearableVideoView extends StatelessWidget {
  final MetaWearablesStreamSession session;
  final BoxFit fit;
  final Widget? placeholder;

  const WearableVideoView({
    super.key,
    required this.session,
    this.fit = BoxFit.contain,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<VideoFrameInfo>(
      stream: session.videoFrameInfo,
      builder: (context, snapshot) {
        final frameInfo = snapshot.data;
        final aspectRatio = frameInfo?.aspectRatio ?? 16 / 9;

        return StreamBuilder<StreamSessionState>(
          stream: session.state,
          builder: (context, stateSnapshot) {
            final state = stateSnapshot.data;
            final isStreaming = state == StreamSessionState.streaming;

            if (!isStreaming && placeholder != null) {
              return AspectRatio(
                aspectRatio: aspectRatio,
                child: Center(child: placeholder!),
              );
            }

            return AspectRatio(
              aspectRatio: aspectRatio,
              child: FittedBox(
                fit: fit,
                child: SizedBox(
                  width: frameInfo?.width.toDouble() ?? 1280,
                  height: frameInfo?.height.toDouble() ?? 720,
                  child: Texture(textureId: session.textureId),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
