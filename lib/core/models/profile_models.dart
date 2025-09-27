
enum ProfileType {
  personal('Personal', 'For friends, family & casual connections'),
  professional('Professional', 'For work, business & networking'),
  custom('Custom', 'Customizable fields for specific needs');

  const ProfileType(this.label, this.description);
  final String label;
  final String description;
}

class ProfileData {
  final String id;
  final ProfileType type;
  final String name;
  final String? title;
  final String? company;
  final String? phone;
  final String? email;
  final String? website;
  final Map<String, String> socialMedia;
  final String? profileImagePath;
  final int templateIndex;
  final DateTime lastUpdated;
  final bool isActive;

  ProfileData({
    required this.id,
    required this.type,
    required this.name,
    this.title,
    this.company,
    this.phone,
    this.email,
    this.website,
    this.socialMedia = const {},
    this.profileImagePath,
    this.templateIndex = 0,
    required this.lastUpdated,
    this.isActive = false,
  });

  ProfileData copyWith({
    String? id,
    ProfileType? type,
    String? name,
    String? title,
    String? company,
    String? phone,
    String? email,
    String? website,
    Map<String, String>? socialMedia,
    String? profileImagePath,
    int? templateIndex,
    DateTime? lastUpdated,
    bool? isActive,
  }) {
    return ProfileData(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      title: title ?? this.title,
      company: company ?? this.company,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      socialMedia: socialMedia ?? this.socialMedia,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      templateIndex: templateIndex ?? this.templateIndex,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'name': name,
      'title': title,
      'company': company,
      'phone': phone,
      'email': email,
      'website': website,
      'socialMedia': socialMedia,
      'profileImagePath': profileImagePath,
      'templateIndex': templateIndex,
      'lastUpdated': lastUpdated.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    return ProfileData(
      id: json['id'],
      type: ProfileType.values.firstWhere((e) => e.name == json['type']),
      name: json['name'],
      title: json['title'],
      company: json['company'],
      phone: json['phone'],
      email: json['email'],
      website: json['website'],
      socialMedia: Map<String, String>.from(json['socialMedia'] ?? {}),
      profileImagePath: json['profileImagePath'],
      templateIndex: json['templateIndex'] ?? 0,
      lastUpdated: DateTime.parse(json['lastUpdated']),
      isActive: json['isActive'] ?? false,
    );
  }

  // Get default fields for each profile type
  static List<String> getDefaultFields(ProfileType type) {
    switch (type) {
      case ProfileType.personal:
        return ['name', 'phone', 'email', 'instagram', 'snapchat', 'tiktok'];
      case ProfileType.professional:
        return ['name', 'title', 'company', 'phone', 'email', 'linkedin', 'website'];
      case ProfileType.custom:
        return ['name', 'phone', 'email'];
    }
  }

  // Get available social media platforms for each profile type
  static List<String> getAvailableSocials(ProfileType type) {
    switch (type) {
      case ProfileType.personal:
        return ['instagram', 'snapchat', 'tiktok', 'twitter', 'facebook', 'discord'];
      case ProfileType.professional:
        return ['linkedin', 'twitter', 'github', 'behance', 'dribbble'];
      case ProfileType.custom:
        return ['instagram', 'snapchat', 'tiktok', 'twitter', 'facebook', 'linkedin', 'github', 'discord', 'behance', 'dribbble', 'youtube', 'twitch'];
    }
  }

  // Create empty profile for a type
  static ProfileData createEmpty(ProfileType type) {
    return ProfileData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      name: '',
      lastUpdated: DateTime.now(),
    );
  }
}

class ProfileSettings {
  final bool multipleProfilesEnabled;
  final String activeProfileId;
  final List<String> profileOrder;

  ProfileSettings({
    this.multipleProfilesEnabled = false,
    required this.activeProfileId,
    this.profileOrder = const [],
  });

  ProfileSettings copyWith({
    bool? multipleProfilesEnabled,
    String? activeProfileId,
    List<String>? profileOrder,
  }) {
    return ProfileSettings(
      multipleProfilesEnabled: multipleProfilesEnabled ?? this.multipleProfilesEnabled,
      activeProfileId: activeProfileId ?? this.activeProfileId,
      profileOrder: profileOrder ?? this.profileOrder,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'multipleProfilesEnabled': multipleProfilesEnabled,
      'activeProfileId': activeProfileId,
      'profileOrder': profileOrder,
    };
  }

  factory ProfileSettings.fromJson(Map<String, dynamic> json) {
    return ProfileSettings(
      multipleProfilesEnabled: json['multipleProfilesEnabled'] ?? false,
      activeProfileId: json['activeProfileId'],
      profileOrder: List<String>.from(json['profileOrder'] ?? []),
    );
  }
}