import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_info_provider.dart';

class AtPeoplePage extends StatefulWidget {
  final String groupId;
  final String currentUserId;

  const AtPeoplePage({
    super.key,
    required this.groupId,
    required this.currentUserId,
  });

  @override
  State<AtPeoplePage> createState() => _AtPeoplePageState();
}

class _AtPeoplePageState extends State<AtPeoplePage> {
  late final Future<List<UserAtInfo>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _membersFuture = _loadMembers();
  }

  Future<List<UserAtInfo>> _loadMembers() async {
    final provider = context.read<UserInfoProvider>();
    final members =
        await provider.getGroupMembersSync(widget.groupId, fromServer: true) ??
        provider.publicGroupMembers[widget.groupId] ??
        const <ExampleGroupMember>[];
    final users = members
        .where((member) => member.userId != widget.currentUserId)
        .map(
          (member) => UserAtInfo(
            userId: member.userId,
            name: member.name.trim().isNotEmpty ? member.name : member.userId,
          ),
        )
        .toList();
    if (users.isEmpty) {
      users.addAll(
        provider.demoFriends
            .where((friend) => friend.userId != widget.currentUserId)
            .map(
              (friend) => UserAtInfo(
                userId: friend.userId ?? '',
                name: friend.remark?.trim().isNotEmpty == true
                    ? friend.remark!
                    : friend.name?.trim().isNotEmpty == true
                    ? friend.name!
                    : friend.userId ?? '',
              ),
            )
            .where((user) => user.userId.isNotEmpty),
      );
    }
    return [const UserAtInfo(userId: 'All', name: 'All'), ...users];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('选择提醒的人')),
      body: FutureBuilder<List<UserAtInfo>>(
        future: _membersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snapshot.data ?? const <UserAtInfo>[];
          if (users.isEmpty) {
            return const Center(child: Text('暂无群成员'));
          }
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                title: Text(user.name),
                onTap: () => Navigator.of(context).pop(user),
              );
            },
          );
        },
      ),
    );
  }
}
