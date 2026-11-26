enum MessageType { text, image, file, contact, location, audio }

class ChatMessageModel {
  final String id;
  final String senderName;
  final String senderPhone;
  final String senderId;
  final String receiverPhone;
  final String receiverId;
  final String text;
  final String time;
  final bool isMe;
  final bool isDelivered;
  final bool isRead;
  final dynamic sentAt;
  final dynamic deliveredAt;
  final dynamic readAt;
  final MessageType type;
  final String mediaPath;
  final String fileName;
  final String fileSize;
  final String contactName;
  final String contactPhone;
  final String locationAddress;
  final int audioDurationSeconds;

  // Stage 1 Action Fields
  final String? replyToMessageId;
  final String? replyToText;
  final String? replyToSenderId;
  final bool isEdited;
  final dynamic editedAt;
  final bool isDeleted;
  final List<String> deletedFor;
  final Map<String, String> reactions;

  const ChatMessageModel({
    required this.id,
    required this.senderName,
    this.senderPhone = '',
    this.senderId = '',
    this.receiverPhone = '',
    this.receiverId = '',
    required this.text,
    required this.time,
    required this.isMe,
    this.isDelivered = false,
    this.isRead = false,
    this.sentAt,
    this.deliveredAt,
    this.readAt,
    this.type = MessageType.text,
    this.mediaPath = '',
    this.fileName = '',
    this.fileSize = '',
    this.contactName = '',
    this.contactPhone = '',
    this.locationAddress = '',
    this.audioDurationSeconds = 0,
    this.replyToMessageId,
    this.replyToText,
    this.replyToSenderId,
    this.isEdited = false,
    this.editedAt,
    this.isDeleted = false,
    this.deletedFor = const [],
    this.reactions = const {},
  });
}
