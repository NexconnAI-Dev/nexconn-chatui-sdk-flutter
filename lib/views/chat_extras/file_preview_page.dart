import 'dart:convert';
import 'dart:io';

import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/chat_provider.dart';
import '../../l10n/nexconn_chat_ui_l10n.dart';
import '../../utils/chatui_asset.dart';

/// Previews and downloads a file message attachment.
class FilePreviewPage extends StatefulWidget {
  static const Key textPreviewKey = ValueKey('file-preview-text-content');
  static const Key openButtonKey = ValueKey('file-preview-open-button');

  final FileMessage fileMessage;
  final ChatProvider? provider;

  const FilePreviewPage({super.key, required this.fileMessage, this.provider});

  @override
  State<FilePreviewPage> createState() => _FilePreviewPageState();
}

class _FilePreviewPageState extends State<FilePreviewPage> {
  late FileMessage _fileMessage;
  double? _downloadProgress;
  bool _isDownloading = false;
  bool _isOpening = false;
  String? _errorText;
  String? _textContent;

  @override
  void initState() {
    super.initState();
    _fileMessage = _resolveLatestFileMessage(widget.fileMessage);
  }

  @override
  void didUpdateWidget(covariant FilePreviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final latest = _resolveLatestFileMessage(widget.fileMessage);
    if (!_isSameMessage(_fileMessage, latest) ||
        _fileMessage.localPath != latest.localPath ||
        _fileMessage.remotePath != latest.remotePath) {
      _fileMessage = latest;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.chatUIL10n;
    final fileName = _fileMessage.name?.trim().isNotEmpty == true
        ? _fileMessage.name!.trim()
        : l10n.fileUntitled;
    final isDownloaded = _fileMessage.localPath?.isNotEmpty == true;
    final isReadableTextFile =
        _isReadableTextFile(fileName) ||
        _isReadableTextFile(_fileMessage.fileType);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.filePreviewTitle),
        actions: [
          IconButton(
            icon: ChatUIAsset.image(
              'NexconnLightIcon/Forward-single.png',
              width: 24,
              height: 24,
              color: isDownloaded
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.38),
            ),
            onPressed: isDownloaded ? _shareDownloadedFile : null,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ChatUIAsset.image(
                      'NexconnLightIcon/File.png',
                      width: 40,
                      height: 40,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatFileSize(_fileMessage.size),
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_downloadProgress != null) ...[
              CircularProgressIndicator(value: _downloadProgress),
              const SizedBox(height: 16),
              Text(
                l10n.fileDownloadProgress(
                  ((_downloadProgress ?? 0) * 100).round(),
                ),
              ),
            ],
            if (_errorText != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Text(
                  _errorText!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFE53935)),
                ),
              ),
            ],
            ElevatedButton(
              onPressed: _isDownloading || isDownloaded ? null : _downloadFile,
              child: Text(
                isDownloaded
                    ? l10n.fileDownloaded
                    : (_isDownloading ? l10n.commonLoading : l10n.fileDownload),
              ),
            ),
            if (isReadableTextFile) ...[
              const SizedBox(height: 8),
              ElevatedButton(
                key: FilePreviewPage.openButtonKey,
                onPressed: !_isDownloading && !_isOpening
                    ? () => _openFile()
                    : null,
                child: Text(_isOpening ? l10n.commonLoading : l10n.fileOpen),
              ),
            ],
            if (_textContent != null) ...[
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  key: FilePreviewPage.textPreviewKey,
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.24),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _textContent!,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openFile() async {
    var path = _shareableLocalPath(_fileMessage.localPath);
    if (path == null && _fileMessage.remotePath?.isNotEmpty == true) {
      await _downloadFile();
      path = _shareableLocalPath(_fileMessage.localPath);
    }
    if (path == null) {
      setState(() => _errorText = context.chatUIL10n.filePathUnavailable);
      return;
    }
    setState(() {
      _isOpening = true;
      _errorText = null;
    });
    try {
      final content = await File(path).readAsBytes();
      if (!mounted) {
        return;
      }
      setState(() {
        _textContent = utf8.decode(content, allowMalformed: true);
        _isOpening = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isOpening = false;
        _errorText = context.chatUIL10n.fileOpenFailed;
      });
    }
  }

  Future<void> _shareDownloadedFile() async {
    final path = _shareableLocalPath(_fileMessage.localPath);
    if (path == null) {
      if (mounted) {
        setState(() => _errorText = context.chatUIL10n.filePathUnavailable);
      }
      return;
    }
    try {
      await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _errorText = context.chatUIL10n.fileOpenFailed);
    }
  }

  Future<void> _downloadFile() async {
    if (_fileMessage.remotePath?.isNotEmpty != true) {
      setState(() => _errorText = context.chatUIL10n.filePathUnavailable);
      return;
    }
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _errorText = null;
    });
    try {
      final provider = widget.provider;
      if (provider != null) {
        await provider.downloadMediaMessage(
          _fileMessage,
          onDownloading: (_, progress) {
            if (!mounted) {
              return;
            }
            setState(() {
              _downloadProgress = (progress.clamp(0, 100)) / 100;
            });
          },
          onDownloaded: (downloaded) {
            if (!mounted || downloaded is! FileMessage) {
              return;
            }
            setState(() {
              _applyDownloadedState(downloaded);
            });
          },
        );
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _downloadProgress = null;
          });
        }
      } else {
        await _downloadDetachedFileMessage();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = null;
          _errorText = context.chatUIL10n.fileDownloadFailed;
        });
      }
    }
  }

  Future<void> _downloadDetachedFileMessage() async {
    final remotePath = _fileMessage.remotePath?.trim();
    if (remotePath == null ||
        remotePath.isEmpty ||
        !remotePath.startsWith(RegExp(r'https?://', caseSensitive: false))) {
      await _downloadWithMessageApi();
      return;
    }
    final localPath = _downloadTargetPath(remotePath);
    await Dio().download(
      remotePath,
      localPath,
      onReceiveProgress: (received, total) {
        if (!mounted || total <= 0) {
          return;
        }
        setState(() {
          _downloadProgress = (received / total).clamp(0, 1).toDouble();
        });
      },
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _fileMessage.localPath = localPath;
      _isDownloading = false;
      _downloadProgress = null;
    });
  }

  Future<void> _downloadWithMessageApi() async {
    final accepted = await _fileMessage.downloadMedia(
      handler: DownloadMediaMessageHandler(
        onProgress: (message, progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _downloadProgress = ((progress ?? 0).clamp(0, 100)) / 100;
          });
        },
        onCanceled: (_) {
          if (!mounted) {
            return;
          }
          setState(() {
            _isDownloading = false;
            _downloadProgress = null;
          });
        },
        onComplete: (code, message) {
          if (!mounted) {
            return;
          }
          setState(() {
            _isDownloading = false;
            _downloadProgress = null;
            if (code == 0 && message is FileMessage) {
              _applyDownloadedState(message);
            } else {
              _errorText = context.chatUIL10n.fileDownloadFailed;
            }
          });
        },
      ),
    );
    if (accepted != 0 && mounted) {
      setState(() {
        _isDownloading = false;
        _downloadProgress = null;
        _errorText = context.chatUIL10n.fileDownloadFailed;
      });
    }
  }

  String _downloadTargetPath(String remotePath) {
    final extension =
        _pathExtension(_fileMessage.name) ??
        _pathExtension(remotePath) ??
        _pathExtension(_fileMessage.fileType) ??
        'file';
    return '${Directory.systemTemp.path}/nexconn_file_${DateTime.now().microsecondsSinceEpoch}.$extension';
  }

  String? _pathExtension(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(text);
    final path = uri?.hasScheme == true && uri?.path.isNotEmpty == true
        ? uri!.path
        : text;
    final fileName = path.split('/').last;
    final index = fileName.lastIndexOf('.');
    if (index < 0 || index == fileName.length - 1) {
      return null;
    }
    return fileName.substring(index + 1).toLowerCase();
  }

  bool _isReadableTextFile(String? value) {
    final text = value?.trim().toLowerCase();
    if (text == null || text.isEmpty) {
      return false;
    }
    if (text.startsWith('text/')) {
      return true;
    }
    const readableMimeTypes = {
      'application/json',
      'application/xml',
      'application/x-ndjson',
      'application/x-yaml',
      'application/yaml',
      'application/csv',
      'text/csv',
      'text/tab-separated-values',
    };
    if (readableMimeTypes.contains(text)) {
      return true;
    }
    const readableExtensions = {
      'txt',
      'log',
      'md',
      'markdown',
      'json',
      'xml',
      'csv',
      'tsv',
      'yaml',
      'yml',
    };
    return readableExtensions.contains(_pathExtension(text));
  }

  FileMessage _resolveLatestFileMessage(FileMessage fallback) {
    final provider = widget.provider;
    if (provider == null) {
      return fallback;
    }
    for (final message in provider.messages) {
      if (message is FileMessage && _isSameMessage(message, fallback)) {
        return message;
      }
    }
    return fallback;
  }

  bool _isSameMessage(Message a, Message b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.messageId != null &&
        b.messageId != null &&
        a.messageId == b.messageId) {
      return true;
    }
    if (a.clientId != null && b.clientId != null && a.clientId == b.clientId) {
      return true;
    }
    return a.channelId == b.channelId &&
        a.senderUserId == b.senderUserId &&
        a.sentTime == b.sentTime;
  }

  void _applyDownloadedState(FileMessage downloaded) {
    widget.fileMessage.localPath = downloaded.localPath;
    _fileMessage = _resolveLatestFileMessage(downloaded);
  }

  String? _shareableLocalPath(String? rawPath) {
    final path = rawPath?.trim();
    if (path == null || path.isEmpty) {
      return null;
    }
    if (path.startsWith('file://')) {
      return Uri.tryParse(path)?.toFilePath();
    }
    return path;
  }

  String _formatFileSize(int? bytes) {
    final size = bytes ?? 0;
    if (size <= 0) {
      return context.chatUIL10n.fileSizeUnknown;
    }
    if (size <= 1024) {
      return '$size bytes';
    }
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = size.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex += 1;
    }
    final text = unitIndex == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(value >= 10 ? 1 : 2);
    return '$text ${units[unitIndex]}';
  }
}
