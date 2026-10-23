part of '../main.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final _composer = TextEditingController();
  final _scrollController = ScrollController();
  bool _isThinking = false;
  final _messages = <_ChatMessage>[
    _ChatMessage(
      text:
          'Hi ${ApiService.currentUser?['name'] ?? 'there'}! I can help you track reports, understand city updates, or submit an infrastructure issue.',
      fromUser: false,
      time: 'Now',
    ),
  ];

  @override
  void dispose() {
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? suggestedText]) async {
    final text = (suggestedText ?? _composer.text).trim();
    if (text.isEmpty || _isThinking) return;
    setState(() {
      _messages.add(_ChatMessage(text: text, fromUser: true, time: 'Now'));
      _composer.clear();
      _isThinking = true;
    });
    _scrollToBottom();
    try {
      final reply = await ApiService.chatbotReply(
        _chatHistoryForRequest(_messages),
      );
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(text: reply, fromUser: false, time: 'Now'));
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            text: error.toString().replaceFirst('Exception: ', ''),
            fromUser: false,
            time: 'Now',
            isError: true,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isThinking = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: AppBar(
      backgroundColor: deepNavy,
      foregroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back),
      ),
      title: const Row(
        children: [
          _BotAvatar(size: 48),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trako',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFB9CBD1), size: 10),
                  SizedBox(width: 5),
                  Text(
                    'Infrastructure help',
                    style: TextStyle(color: Color(0xFFB9CBD1), fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {},
          tooltip: 'More options',
          icon: const Icon(Icons.more_vert),
        ),
      ],
    ),
    body: PageEntrance(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
              children: [
                const _ChatIntro(),
                const SizedBox(height: 18),
                const Text(
                  'SUGGESTED QUESTIONS',
                  style: TextStyle(
                    color: inkSoft,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      [
                            'Where is my report?',
                            'How do I report an issue?',
                            'What is happening in Mati?',
                          ]
                          .map(
                            (prompt) => ActionChip(
                              label: Text(prompt),
                              onPressed: () => _send(prompt),
                              backgroundColor: Colors.white.withValues(
                                alpha: .78,
                              ),
                              side: const BorderSide(color: line),
                              shape: const StadiumBorder(),
                              labelStyle: const TextStyle(
                                color: navy,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 22),
                ..._messages.map((message) => _MessageBubble(message: message)),
                if (_isThinking)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: _BotAvatar(size: 104, thinking: true),
                    ),
                  ),
              ],
            ),
          ),
          _Composer(controller: _composer, onSend: _send),
        ],
      ),
    ),
  );
}

List<Map<String, String>> _chatHistoryForRequest(List<_ChatMessage> messages) {
  final conversation = messages
      .where((message) => !message.isError)
      .skip(1)
      .toList();
  final recentMessages = conversation.skip(
    (conversation.length - 12).clamp(0, conversation.length).toInt(),
  );
  return recentMessages
      .map(
        (message) => {
          'role': message.fromUser ? 'user' : 'assistant',
          'content': message.text.length > 2000
              ? message.text.substring(0, 2000)
              : message.text,
        },
      )
      .toList();
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.fromUser,
    required this.time,
    this.isError = false,
  });
  final String text, time;
  final bool fromUser;
  final bool isError;
}

class _BotAvatar extends StatelessWidget {
  const _BotAvatar({
    this.size = 72,
    this.welcome = false,
    this.thinking = false,
  });
  final double size;
  final bool welcome;
  final bool thinking;

  @override
  Widget build(BuildContext context) => Image.asset(
    thinking
        ? 'assets/chatbot_character/thinking_animation/infratrack_mascot_hand_thinking.gif'
        : welcome
        ? 'assets/chatbot_character/chatbot_face/thumbs_up.png'
        : 'assets/chatbot_character/chatbot_face/profile.png',
    width: size,
    height: size + 7,
    fit: BoxFit.contain,
    errorBuilder: (_, _, _) =>
        Icon(Icons.auto_awesome, color: teal, size: size * .45),
  );
}

class _ChatIntro extends StatelessWidget {
  const _ChatIntro();

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _BotAvatar(size: 104, welcome: true),
      const SizedBox(width: 11),
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .82),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            border: Border.all(color: Colors.white.withValues(alpha: .9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good to see you, ${ApiService.currentUser?['name'] ?? 'neighbor'}',
                style: TextStyle(
                  color: navy,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'I’m your local infrastructure guide. Ask me anything about reports and city services.',
                style: TextStyle(color: inkSoft, fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final _ChatMessage message;
  @override
  Widget build(BuildContext context) => Align(
    alignment: message.fromUser ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 290),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: message.fromUser ? navy : Colors.white.withValues(alpha: .84),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(17),
          topRight: const Radius.circular(17),
          bottomLeft: Radius.circular(message.fromUser ? 17 : 4),
          bottomRight: Radius.circular(message.fromUser ? 4 : 17),
        ),
        border: message.fromUser
            ? null
            : Border.all(color: Colors.white.withValues(alpha: .9)),
      ),
      child: Column(
        crossAxisAlignment: message.fromUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            message.text,
            style: TextStyle(
              color: message.fromUser ? Colors.white : ink,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message.time,
            style: TextStyle(
              color: message.fromUser ? Colors.white60 : inkSoft,
              fontSize: 9,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});
  final TextEditingController controller;
  final VoidCallback onSend;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .82),
      border: Border(
        top: BorderSide(color: Colors.white.withValues(alpha: .9)),
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            maxLength: 2000,
            minLines: 1,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              counterText: '',
              hintText: 'Ask the assistant...',
              prefixIcon: Icon(Icons.edit_outlined, size: 18, color: inkSoft),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: clay,
          shape: const CircleBorder(),
          child: IconButton(
            onPressed: onSend,
            tooltip: 'Send message',
            color: Colors.white,
            icon: const Icon(Icons.arrow_upward),
          ),
        ),
      ],
    ),
  );
}
