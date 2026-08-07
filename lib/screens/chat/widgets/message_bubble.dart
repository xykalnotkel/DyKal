import 'package:flutter/material.dart';
import 'package:flutter/material.dart'; // phosphor replaced with Material Icons
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/theme.dart';
import '../../../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final VoidCallback onSwipeReply;
  final VoidCallback onLove;
  final Function(String) onEdit;
  final VoidCallback onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.onSwipeReply,
    required this.onLove,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 4),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.block(), size: 14, color: Colors.grey),
            SizedBox(width: 6),
            Text("Pesan ini telah dihapus", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 13)),
          ]),
        ),
      );
    }

    // View Once handling
    if (message.isViewOnce && !isMe && !message.viewOnceOpened) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onTap: () {
            // Buka sekali, tandai opened
            showDialog(context: context, builder: (_) => Dialog(
              backgroundColor: Colors.black,
              child: Stack(children: [
                CachedNetworkImage(imageUrl: message.imageUrl!, fit: BoxFit.contain),
                Positioned(top: 12, right: 12, child: IconButton(onPressed: ()=> Navigator.pop(context), icon: Icon(Icons.close, color: Colors.white))),
              ]),
            ));
            // Update Firestore viewOnceOpened = true (nanti auto hapus)
          },
          child: Container(
            margin: EdgeInsets.symmetric(vertical: 4),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: DyKalTheme.dykalGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.visibility(), color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text("Foto sekali lihat", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
    }

    return Dismissible(
      key: Key(message.id),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async { onSwipeReply(); return false; },
      background: Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(left: 16), child: Icon(Icons.reply(), color: DyKalTheme.primary))),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () => _showOptions(context),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                margin: EdgeInsets.symmetric(vertical: 4),
                padding: EdgeInsets.all(message.type == MessageType.image ? 4 : 12),
                decoration: BoxDecoration(
                  color: isMe ? DyKalTheme.primary : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                  border: isMe ? null : Border.all(color: DyKalTheme.borderSoft),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (message.imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(imageUrl: message.imageUrl!, fit: BoxFit.cover, placeholder: (_, __) => Container(height: 180, color: DyKalTheme.borderSoft)),
                    ),
                  if (message.text.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: message.imageUrl != null ? 8 : 0),
                      child: Text(message.text, style: TextStyle(color: isMe ? Colors.white : DyKalTheme.textDark, fontSize: 14)),
                    ),
                  SizedBox(height: 4),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    if (message.isEdited) Text("diedit • ", style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : DyKalTheme.textGrey)),
                    Text(_formatTime(message.createdAt), style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : DyKalTheme.textGrey)),
                    if (isMe) ...[
                      SizedBox(width: 4),
                      _statusIcon(),
                    ],
                  ]),
                ]),
              ),
              // Love icon
              if (message.isLoved)
                Positioned(
                  bottom: -6, right: isMe ? null : -6, left: isMe ? -6 : null,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                    child: Icon(Icons.favorite, color: DyKalTheme.primary, size: 14),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusIcon() {
    switch (message.status) {
      case MessageStatus.sending: return Icon(Icons.schedule(), size: 12, color: Colors.white70);
      case MessageStatus.sent: return Icon(Icons.check(), size: 12, color: Colors.white70); // centang 1
      case MessageStatus.delivered: return Icon(Icons.done_all(), size: 12, color: Colors.white70); // centang 2 abu
      case MessageStatus.read: return Icon(Icons.done_all(), size: 12, color: Color(0xFF00D68F)); // centang 2 biru/hijau
    }
  }

  String _formatTime(dynamic ts) {
    try { return "${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2,'0')}"; } catch (_) { return ""; }
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(context: context, shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: Icon(Icons.favorite(), color: DyKalTheme.primary), title: Text(message.isLoved ? "Hapus Love" : "Love Pesan"), onTap: (){ Navigator.pop(context); onLove(); }),
        ListTile(leading: Icon(Icons.reply()), title: Text("Balas (Swipe)"), onTap: (){ Navigator.pop(context); onSwipeReply(); }),
        if (isMe) ListTile(leading: Icon(Icons.edit()), title: Text("Edit Pesan"), onTap: (){
          Navigator.pop(context);
          final c = TextEditingController(text: message.text);
          showDialog(context: context, builder: (_) => AlertDialog(title: Text("Edit Pesan"), content: TextField(controller: c), actions: [TextButton(onPressed: ()=> Navigator.pop(context), child: Text("Batal")), FilledButton(onPressed: (){ Navigator.pop(context); onEdit(c.text); }, child: Text("Simpan"))]));
        }),
        if (isMe) ListTile(leading: Icon(Icons.delete(), color: Colors.red), title: Text("Hapus Pesan", style: TextStyle(color: Colors.red)), onTap: (){ Navigator.pop(context); onDelete(); }),
      ]),
    ));
  }
}
