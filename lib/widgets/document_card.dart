import 'package:flutter/material.dart';
import '../models/document.dart';

/// A card widget that displays metadata for a single [Document].
class DocumentCard extends StatelessWidget {
  final Document document;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const DocumentCard({
    super.key,
    required this.document,
    required this.onTap,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildThumbnail(theme),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfo(theme),
              ),
              _buildActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(ThemeData theme) {
    return Container(
      width: 52,
      height: 68,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf,
            color: theme.colorScheme.primary,
            size: 28,
          ),
          const SizedBox(height: 2),
          Text(
            'PDF',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfo(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          document.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.insert_drive_file,
                size: 13, color: theme.colorScheme.outline),
            const SizedBox(width: 3),
            Text(
              '${document.pageCount} ${document.pageCount == 1 ? 'page' : 'pages'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(width: 10),
            _buildSizeChip(theme),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _formatDate(document.createdAt),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildSizeChip(ThemeData theme) {
    final isUnder = document.isUnderSizeLimit;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isUnder
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUnder ? Icons.check_circle : Icons.warning,
            size: 11,
            color: isUnder
                ? theme.colorScheme.primary
                : theme.colorScheme.error,
          ),
          const SizedBox(width: 3),
          Text(
            document.fileSizeLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isUnder
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return PopupMenuButton<_Action>(
      onSelected: (action) {
        switch (action) {
          case _Action.share:
            onShare();
          case _Action.delete:
            onDelete();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: _Action.share,
          child: ListTile(
            leading: Icon(Icons.share),
            title: Text('Share'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: _Action.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.red),
            title: Text('Delete', style: TextStyle(color: Colors.red)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.isNegative) {
      // Clock skew: date is in the future – just show the date.
      return '${dt.day}/${dt.month}/${dt.year}';
    } else if (diff.inDays == 0) {
      return 'Today ${_twoDigit(dt.hour)}:${_twoDigit(dt.minute)}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  String _twoDigit(int n) => n.toString().padLeft(2, '0');
}

enum _Action { share, delete }
