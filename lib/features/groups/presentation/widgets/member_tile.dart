import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/group_member_model.dart';

class MemberTile extends StatelessWidget {
  const MemberTile({
    required this.member,
    super.key,
  });

  final GroupMemberModel member;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.deepForest,
          child: Text(
            member.fullName.isEmpty ? '?' : member.fullName[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(member.fullName),
        subtitle: Text(member.email),
        trailing: Text(
          member.memberRole,
          style: const TextStyle(
            color: AppColors.signalOrange,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
