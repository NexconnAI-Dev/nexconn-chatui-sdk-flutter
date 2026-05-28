import 'dart:async';
import 'dart:convert';

import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/http_util.dart';

class ExampleGroupMember {
  final String userId;
  final String name;
  final String portraitUri;

  const ExampleGroupMember({
    required this.userId,
    required this.name,
    this.portraitUri = '',
  });

  factory ExampleGroupMember.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : json;
    return ExampleGroupMember(
      userId: (user['id'] ?? json['userId'] ?? '').toString(),
      name:
          (user['nickname'] ??
                  user['nickName'] ??
                  user['name'] ??
                  json['groupNickname'] ??
                  '')
              .toString(),
      portraitUri: (user['portraitUri'] ?? user['portrait'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'userId': userId,
    'name': name,
    'portraitUri': portraitUri,
  };
}

class UserInfoProvider extends ChangeNotifier {
  final Map<String, NexconnUserProfile> _userCache =
      <String, NexconnUserProfile>{
        'demo_user': const NexconnUserProfile(
          userId: 'demo_user',
          name: 'Demo User',
          email: 'demo@nexconn.example',
        ),
        'user1': const NexconnUserProfile(userId: 'user1', name: 'User One'),
        'user2': const NexconnUserProfile(userId: 'user2', name: 'User Two'),
        'user3': const NexconnUserProfile(userId: 'user3', name: 'User Three'),
        'alice': const NexconnUserProfile(userId: 'alice', name: 'Alice'),
        'bob': const NexconnUserProfile(userId: 'bob', name: 'Bob'),
        'carol': const NexconnUserProfile(userId: 'carol', name: 'Carol'),
      };

  final Map<String, GroupInfo> _groupCache = <String, GroupInfo>{
    'flutter_dev': GroupInfo(
      groupId: 'flutter_dev',
      groupName: 'Flutter Dev',
      introduction: 'Nexconn Chat UI demo group',
      notice: 'Welcome to the demo group.',
    ),
    'product_team': GroupInfo(
      groupId: 'product_team',
      groupName: 'Product Team',
      introduction: 'Product discussion group',
    ),
  };

  final Map<String, List<ExampleGroupMember>> _groupMemberCache =
      <String, List<ExampleGroupMember>>{};
  final Set<String> _fetchingUserIds = <String>{};
  final Set<String> _fetchingGroupIds = <String>{};
  final Set<String> _fetchingGroupMemberIds = <String>{};
  final Map<String, Future<NexconnUserProfile?>> _pendingUserRequests =
      <String, Future<NexconnUserProfile?>>{};

  Map<String, NexconnUserProfile> get publicUserInfos => _userCache;
  Map<String, List<ExampleGroupMember>> get publicGroupMembers =>
      _groupMemberCache;

  List<FriendInfo> get demoFriends => _userCache.values
      .where((user) => user.userId != 'demo_user')
      .map(
        (user) => FriendInfo(
          userId: user.userId,
          name: user.name,
          remark: user.name,
          avatarUrl: user.avatarUrl,
        ),
      )
      .toList(growable: false);

  List<GroupInfo> get demoGroups => _groupCache.values.toList();

  NexconnUserProfile? getUserInfo(String userId, {bool fromServer = false}) {
    if (_userCache.containsKey(userId)) return _userCache[userId];
    _fetchAndCacheUserInfo(userId, fromServer: fromServer);
    return null;
  }

  GroupInfo? getGroupInfo(String groupId, {bool fromServer = false}) {
    if (_groupCache.containsKey(groupId)) return _groupCache[groupId];
    _fetchAndCacheGroupInfo(groupId, fromServer: fromServer);
    return null;
  }

  Future<NexconnUserProfile?> getUserProfile(String? userId) async {
    final id = userId?.trim();
    if (id == null || id.isEmpty) return _userCache['demo_user'];
    return getUserInfoSync(id);
  }

  Future<NexconnUserProfile?> getUserInfoSync(
    String userId, {
    bool fromServer = false,
  }) async {
    if (_userCache.containsKey(userId)) return _userCache[userId];
    return _fetchAndCacheUserInfo(userId, fromServer: fromServer);
  }

  Future<GroupInfo?> getGroupInfoSync(
    String groupId, {
    bool fromServer = false,
  }) async {
    if (_groupCache.containsKey(groupId)) return _groupCache[groupId];
    return _fetchAndCacheGroupInfo(groupId, fromServer: fromServer);
  }

  List<ExampleGroupMember>? getGroupMembers(
    String groupId, {
    bool fromServer = false,
  }) {
    if (_groupMemberCache.containsKey(groupId)) {
      return _groupMemberCache[groupId];
    }
    _fetchAndCacheGroupMembers(groupId, fromServer: fromServer);
    return null;
  }

  Future<List<ExampleGroupMember>?> getGroupMembersSync(
    String groupId, {
    bool fromServer = false,
  }) async {
    if (_groupMemberCache.containsKey(groupId)) {
      return _groupMemberCache[groupId];
    }
    return _fetchAndCacheGroupMembers(groupId, fromServer: fromServer);
  }

  Future<NexconnUserProfile?> _fetchAndCacheUserInfo(
    String userId, {
    bool fromServer = false,
  }) async {
    if (_pendingUserRequests.containsKey(userId)) {
      return _pendingUserRequests[userId];
    }
    final completer = Completer<NexconnUserProfile?>();
    _pendingUserRequests[userId] = completer.future;
    _fetchingUserIds.add(userId);
    try {
      final prefs = await SharedPreferences.getInstance();
      NexconnUserProfile? profile;
      final cacheKey = 'user_$userId';
      if (!fromServer && prefs.containsKey(cacheKey)) {
        final cached = prefs.getString(cacheKey);
        if (cached != null) {
          profile = _profileFromJson(
            json.decode(cached) as Map<String, dynamic>,
          );
        }
      } else {
        profile = await _fetchUserInfoFromServer(userId);
        if (profile != null) {
          await prefs.setString(cacheKey, json.encode(_profileToJson(profile)));
        }
      }
      if (profile != null) {
        _userCache[userId] = profile;
        notifyListeners();
      }
      completer.complete(
        profile ?? NexconnUserProfile(userId: userId, name: userId),
      );
      return completer.future;
    } catch (error) {
      completer.complete(null);
      debugPrint('获取用户信息失败: $error');
      return null;
    } finally {
      _fetchingUserIds.remove(userId);
      _pendingUserRequests.remove(userId);
    }
  }

  Future<NexconnUserProfile?> _fetchUserInfoFromServer(String userId) async {
    final response = await ExampleHTTPUtility().request<Map<String, dynamic>>(
      HTTPMethod.get,
      'user/$userId',
    );
    if (!response.isSuccess || response.data == null) return null;
    final content = response.data!;
    final result = content['result'] is Map<String, dynamic>
        ? content['result'] as Map<String, dynamic>
        : content;
    return NexconnUserProfile(
      userId: (result['id'] ?? userId).toString(),
      name: (result['nickname'] ?? result['nickName'] ?? result['name'] ?? '')
          .toString(),
      avatarUrl: (result['portraitUri'] ?? result['portrait'] ?? '').toString(),
    );
  }

  Future<GroupInfo?> _fetchAndCacheGroupInfo(
    String groupId, {
    bool fromServer = false,
  }) async {
    if (_fetchingGroupIds.contains(groupId)) return null;
    _fetchingGroupIds.add(groupId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'group_$groupId';
      GroupInfo? groupInfo;
      if (!fromServer && prefs.containsKey(cacheKey)) {
        final cached = prefs.getString(cacheKey);
        if (cached != null) {
          groupInfo = _groupFromJson(
            json.decode(cached) as Map<String, dynamic>,
          );
        }
      } else {
        groupInfo = await _fetchGroupInfoFromServer(groupId);
        if (groupInfo != null) {
          await prefs.setString(cacheKey, json.encode(_groupToJson(groupInfo)));
        }
      }
      if (groupInfo != null) {
        _groupCache[groupId] = groupInfo;
        notifyListeners();
      }
      return groupInfo;
    } finally {
      _fetchingGroupIds.remove(groupId);
    }
  }

  Future<GroupInfo?> _fetchGroupInfoFromServer(String groupId) async {
    final response = await ExampleHTTPUtility().request<Map<String, dynamic>>(
      HTTPMethod.get,
      'group/$groupId',
    );
    if (!response.isSuccess || response.data == null) return null;
    final result = response.data!['result'] as Map<String, dynamic>?;
    if (result == null) return null;
    return GroupInfo(
      groupId: (result['id'] ?? groupId).toString(),
      groupName: (result['name'] ?? '').toString(),
      avatarUrl: (result['portraitUri'] ?? '').toString(),
    );
  }

  Future<List<ExampleGroupMember>?> _fetchAndCacheGroupMembers(
    String groupId, {
    bool fromServer = false,
  }) async {
    if (_fetchingGroupMemberIds.contains(groupId)) return null;
    _fetchingGroupMemberIds.add(groupId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'groupMember_$groupId';
      List<ExampleGroupMember>? members;
      if (!fromServer && prefs.containsKey(cacheKey)) {
        final cached = prefs.getString(cacheKey);
        if (cached != null) {
          final list = json.decode(cached) as List<dynamic>;
          members = list
              .map(
                (e) => ExampleGroupMember.fromJson(e as Map<String, dynamic>),
              )
              .toList();
        }
      } else {
        members = await _fetchGroupMembersFromServer(groupId);
        if (members != null) {
          await prefs.setString(
            cacheKey,
            json.encode(members.map((e) => e.toJson()).toList()),
          );
        }
      }
      if (members != null) {
        _groupMemberCache[groupId] = members;
        notifyListeners();
      }
      return members;
    } finally {
      _fetchingGroupMemberIds.remove(groupId);
    }
  }

  Future<List<ExampleGroupMember>?> _fetchGroupMembersFromServer(
    String groupId,
  ) async {
    final response = await ExampleHTTPUtility().request<Map<String, dynamic>>(
      HTTPMethod.get,
      'group/$groupId/members',
    );
    if (!response.isSuccess || response.data == null) return null;
    final list = response.data!['result'] as List<dynamic>?;
    return list
        ?.map((e) => ExampleGroupMember.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _userCache.clear();
    _groupCache.clear();
    _groupMemberCache.clear();
    _fetchingUserIds.clear();
    _fetchingGroupIds.clear();
    _fetchingGroupMemberIds.clear();
    notifyListeners();
  }

  Map<String, dynamic> _profileToJson(NexconnUserProfile profile) =>
      <String, dynamic>{
        'userId': profile.userId,
        'name': profile.name,
        'avatarUrl': profile.avatarUrl,
      };

  NexconnUserProfile _profileFromJson(Map<String, dynamic> json) =>
      NexconnUserProfile(
        userId: (json['userId'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        avatarUrl: (json['avatarUrl'] ?? '').toString(),
      );

  Map<String, dynamic> _groupToJson(GroupInfo group) => <String, dynamic>{
    'groupId': group.groupId,
    'groupName': group.groupName,
    'avatarUrl': group.avatarUrl,
  };

  GroupInfo _groupFromJson(Map<String, dynamic> json) => GroupInfo(
    groupId: (json['groupId'] ?? '').toString(),
    groupName: (json['groupName'] ?? '').toString(),
    avatarUrl: (json['avatarUrl'] ?? '').toString(),
  );
}
