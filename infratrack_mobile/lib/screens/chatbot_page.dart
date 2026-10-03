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
    const _ChatMessage(
      text: 'Hi Elena! I can help you track reports, understand city updates, or submit an infrastructure issue.',
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

  void _send([String? suggestedText]) {
    final text = (suggestedText ?? _composer.text).trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(text: text, fromUser: true, time: 'Now'));
      _composer.clear();
      _isThinking = true;
    });
    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      setState(() {
        _isThinking = false;
        _messages.add(
          const _ChatMessage(
            text: 'I can help with that. Check My Reports for live status updates, or use Report an issue to send a new concern to the city team.',
            fromUser: false,
            time: 'Now',
          ),
        );
      });
      _scrollToBottom();
    });
    _scrollToBottom();
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
    backgroundColor: sand,
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
                  Icon(Icons.circle, color: Color(0xFF5FD9C7), size: 8),
                  SizedBox(width: 5),
                  Text(
                    'Online · replies in seconds',
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

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.fromUser,
    required this.time,
  });
  final String text, time;
  final bool fromUser;
}

class _BotAvatar extends StatefulWidget {
  const _BotAvatar({
    this.size = 72,
    this.welcome = false,
    this.thinking = false,
  });
  final double size;
  final bool welcome;
  final bool thinking;
  @override
  State<_BotAvatar> createState() => _BotAvatarState();
}

class _BotAvatarState extends State<_BotAvatar>
    with SingleTickerProviderStateMixin {
  static const _thinkingFrames = [
    'assets/chatbot_character/thinking_animation/thinking1.png',
    'assets/chatbot_character/thinking_animation/thinking2.png',
    'assets/chatbot_character/thinking_animation/thinking3.png',
    'assets/chatbot_character/thinking_animation/thinking4.png',
  ];

  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.thinking) {
      // Thinking is a one-way sequence: once frame 4 is reached, hold it
      // until the response arrives instead of playing back through frame 3.
      _animation.forward();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    builder: (context, _) {
      final wave = (Curves.easeInOut.transform(_animation.value) * 2) - 1;
      final frame = (_animation.value * _thinkingFrames.length).floor().clamp(
        0,
        _thinkingFrames.length - 1,
      );
      return Transform.translate(
        offset: widget.thinking ? Offset(wave * 5, 0) : Offset.zero,
        child: Transform.rotate(
          angle: widget.thinking ? wave * .10 : 0,
          child: Transform.scale(
            scale: 1,
            child: Image.asset(
              widget.thinking
                  ? _thinkingFrames[frame]
                  : widget.welcome
                  ? 'assets/chatbot_character/chatbot_face/thumbs_up.png'
                  : 'assets/chatbot_character/chatbot_face/profile.png',
              width: widget.size,
              height: widget.size + 7,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(
                Icons.auto_awesome,
                color: teal,
                size: widget.size * .45,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ChatIntro extends StatelessWidget {
  const _ChatIntro();
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _BotAvatar(size: 104, welcome: true),
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
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good to see you, Elena 👋',
                style: TextStyle(
                  color: navy,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              SizedBox(height: 5),
              Text(
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
            onSubmitted: (_) => onSend(),
            textInputAction: TextInputAction.send,
            decoration: const InputDecoration(
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
