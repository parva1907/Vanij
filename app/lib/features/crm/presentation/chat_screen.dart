import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/security/phone_cipher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../data/chat_repository.dart';
import '../data/models/chat_message.dart';
import '../data/models/customer.dart';
import '../providers/crm_providers.dart';

/// WhatsApp-style chat for a single customer.
///
/// Riverpod providers consumed:
///   * `customerByIdProvider(customerId)` — live customer doc
///   * `chatHistoryProvider(customerId)`  — live newest-first messages
///   * `chatRepositoryProvider`           — send / edit
///   * `phoneCipherProvider`              — decrypt phone for header
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.customerId});

  final String customerId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _composer = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _composer.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            customerId: widget.customerId,
            draft: ChatMessage(
              id: '',
              sender: ChatSender.merchant,
              body: body,
              createdAt: DateTime.now(),
            ),
          );
      _composer.clear();
    } catch (_) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.genericError)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _editMessage(ChatMessage msg) async {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController(text: msg.body);
    final newBody = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.crmMessageEdit),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 6,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(l.crmMessageEditSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newBody == null || newBody.isEmpty || newBody == msg.body) return;
    try {
      await ref
          .read(chatRepositoryProvider)
          .editMessage(
            customerId: widget.customerId,
            message: msg.copyWith(body: newBody, edited: true),
          );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.genericError)));
    }
  }

  Future<void> _deleteMessage(ChatMessage msg) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.crmMessageDelete),
        content: Text(l.inventoryDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l.crmMessageDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(chatRepositoryProvider)
          .deleteMessage(customerId: widget.customerId, messageId: msg.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.genericError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final customer = ref.watch(customerByIdProvider(widget.customerId));
    final history = ref.watch(chatHistoryProvider(widget.customerId));

    return Scaffold(
      appBar: AppBar(
        title: customer.when(
          loading: () => const Text('…'),
          error: (_, _) => Text(l.genericError),
          data: (c) => Text(c?.name ?? ''),
        ),
        actions: [
          IconButton(
            tooltip: l.crmEditCustomer,
            icon: const Icon(Icons.edit_note),
            onPressed: () {
              final c = customer.asData?.value;
              if (c != null) {
                context.push(VanijRoutes.customerEdit(c.id), extra: c);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            customer.maybeWhen(
              data: (c) => c == null
                  ? const SizedBox.shrink()
                  : _CustomerHeader(customer: c),
              orElse: () => const SizedBox.shrink(),
            ),
            const Divider(height: 1),
            Expanded(
              child: history.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator.adaptive()),
                error: (_, _) => Center(child: Text(l.genericError)),
                data: (msgs) {
                  if (msgs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l.crmNoMessagesYet,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: VanijColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: msgs.length,
                    itemBuilder: (context, i) => _MessageBubble(
                      message: msgs[i],
                      onEdit: () => _editMessage(msgs[i]),
                      onDelete: () => _deleteMessage(msgs[i]),
                    ),
                  );
                },
              ),
            ),
            _Composer(
              controller: _composer,
              onSend: _send,
              sending: _sending,
              hint: l.crmComposerHint,
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerHeader extends ConsumerWidget {
  const _CustomerHeader({required this.customer});
  final Customer customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String>(
      future: ref.read(phoneCipherProvider).decrypt(customer.phoneEncrypted),
      builder: (context, snap) {
        final l = AppLocalizations.of(context);
        final phone = snap.data;
        final failed = snap.hasError;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              const Icon(Icons.phone, size: 18, color: VanijColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  failed ? l.crmCustomerDecryptFailed : (phone ?? '•••'),
                  style: TextStyle(
                    color: failed ? Colors.red : VanijColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (customer.tags.isNotEmpty)
                Wrap(
                  spacing: 6,
                  children: [
                    for (final t in customer.tags.take(3))
                      Chip(
                        label: Text(t, style: const TextStyle(fontSize: 11)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.onEdit,
    required this.onDelete,
  });

  final ChatMessage message;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isMerchant = message.sender == ChatSender.merchant;
    final isAgent = message.sender == ChatSender.agent;
    final bubbleColor = isMerchant
        ? const Color(0xFFDCF8C6) // WhatsApp green tint
        : isAgent
        ? VanijColors.backgroundTint
        : Colors.white;
    final align = isMerchant ? Alignment.centerRight : Alignment.centerLeft;
    final senderLabel = isMerchant
        ? l.crmSenderMerchant
        : isAgent
        ? l.crmSenderAgent
        : l.crmSenderCustomer;

    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: GestureDetector(
          onLongPress: () {
            showModalBottomSheet<void>(
              context: context,
              builder: (ctx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: Text(l.crmMessageEdit),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        onEdit();
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                      ),
                      title: Text(
                        l.crmMessageDelete,
                        style: const TextStyle(color: Colors.red),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        onDelete();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: VanijColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  senderLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: VanijColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(message.body),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(message.createdAt.toLocal()),
                      style: const TextStyle(
                        fontSize: 10,
                        color: VanijColors.textSecondary,
                      ),
                    ),
                    if (message.edited) ...[
                      const SizedBox(width: 4),
                      Text(
                        '· ${l.crmMessageEditedBadge}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: VanijColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.sending,
    required this.hint,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: VanijColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(hintText: hint, isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send),
            style: IconButton.styleFrom(
              backgroundColor: VanijColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
