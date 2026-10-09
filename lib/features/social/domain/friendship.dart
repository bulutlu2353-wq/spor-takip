/// Benim açımdan bir arkadaşlık satırı.
enum FriendshipState { incoming, outgoing, friends }

class Friendship {
  const Friendship({
    required this.requester,
    required this.addressee,
    required this.accepted,
    required this.createdAt,
  });

  final String requester;
  final String addressee;
  final bool accepted;
  final DateTime createdAt;

  FriendshipState stateFor(String me) {
    if (accepted) return FriendshipState.friends;
    return requester == me ? FriendshipState.outgoing : FriendshipState.incoming;
  }

  String otherThan(String me) => requester == me ? addressee : requester;

  factory Friendship.fromJson(Map<String, dynamic> json) => Friendship(
        requester: json['requester'] as String,
        addressee: json['addressee'] as String,
        accepted: json['status'] == 'accepted',
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );
}
