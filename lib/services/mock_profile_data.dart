import 'dart:math';

import '../models/unified_models.dart';

/// Mock profile data for testing NFC sharing functionality
class MockProfileData {
  /// Professional profile for business networking
  static ProfileData get professionalProfile => ProfileData(
    id: 'user_prof_001',
    type: ProfileType.professional,
    name: 'Dr. Sarah Chen',
    title: 'Senior Product Manager',
    company: 'InnovateTech Solutions',
    email: 'sarah.chen@innovatetech.com',
    phone: '+1-555-0123',
    website: 'https://sarahchen.tech',
    socialMedia: {
      'linkedin': 'https://linkedin.com/in/sarahchenpm',
      'twitter': 'https://twitter.com/sarah_builds',
      'github': 'https://github.com/sarahchen-dev'
    },
    profileImagePath: '/mock/photos/sarah.jpg',
    lastUpdated: DateTime.now().subtract(const Duration(days: 7)),
    isActive: true,
  );

  /// Social/personal profile for casual connections
  static ProfileData get socialProfile => ProfileData(
    id: 'user_social_002',
    type: ProfileType.personal,
    name: 'Tyler Brooks',
    title: 'Fitness Coach & Content Creator',
    email: 'tyler.brooks@gmail.com',
    phone: '+1-555-0987',
    website: 'https://tylerfit.com',
    socialMedia: {
      'instagram': 'https://instagram.com/tylerfit',
      'tiktok': 'https://tiktok.com/@tyler_trains',
      'youtube': 'https://youtube.com/c/TylerFitnessChannel'
    },
    profileImagePath: '/mock/photos/tyler.jpg',
    lastUpdated: DateTime.now().subtract(const Duration(days: 2)),
    isActive: true,
  );

  /// Minimal profile with basic contact info only
  static ProfileData get minimalProfile => ProfileData(
    id: 'user_minimal_003',
    type: ProfileType.personal,
    name: 'Alex Kim',
    email: 'alex.kim.contact@gmail.com',
    phone: '+1-555-0456',
    socialMedia: const {},
    lastUpdated: DateTime.now().subtract(const Duration(days: 30)),
    isActive: false,
  );

  /// Custom profile with mixed professional/personal elements
  static ProfileData get customProfile => ProfileData(
    id: 'user_custom_004',
    type: ProfileType.custom,
    name: 'Maya Rodriguez',
    title: 'Freelance UX Designer',
    company: 'Rodriguez Design Studio',
    email: 'hello@mayarodriguez.design',
    phone: '+1-555-0789',
    website: 'https://mayarodriguez.design',
    socialMedia: {
      'behance': 'https://behance.net/mayarodriguez',
      'dribbble': 'https://dribbble.com/mayar',
      'linkedin': 'https://linkedin.com/in/mayarodriguez',
      'instagram': 'https://instagram.com/maya_designs'
    },
    profileImagePath: '/mock/photos/maya.jpg',
    lastUpdated: DateTime.now().subtract(const Duration(days: 1)),
    isActive: true,
  );

  /// Enterprise profile with complete professional information
  static ProfileData get enterpriseProfile => ProfileData(
    id: 'user_enterprise_005',
    type: ProfileType.professional,
    name: 'James Peterson',
    title: 'Chief Technology Officer',
    company: 'Fortune Tech Corp',
    email: 'j.peterson@fortunetech.com',
    phone: '+1-555-0100',
    website: 'https://fortunetech.com',
    socialMedia: {
      'linkedin': 'https://linkedin.com/in/jamespeterson',
      'twitter': 'https://twitter.com/jpeterson_cto'
    },
    profileImagePath: '/mock/photos/james.jpg',
    lastUpdated: DateTime.now().subtract(const Duration(hours: 6)),
    isActive: true,
  );

  /// Student profile for academic/networking events
  static ProfileData get studentProfile => ProfileData(
    id: 'user_student_006',
    type: ProfileType.custom,
    name: 'Zoe Williams',
    title: 'Computer Science Student',
    company: 'Stanford University',
    email: 'zoe.williams@stanford.edu',
    phone: '+1-555-0200',
    website: 'https://zoe-williams.dev',
    socialMedia: {
      'github': 'https://github.com/zoewilliams',
      'linkedin': 'https://linkedin.com/in/zoe-williams-cs',
      'twitter': 'https://twitter.com/zoe_codes'
    },
    profileImagePath: '/mock/photos/zoe.jpg',
    lastUpdated: DateTime.now().subtract(const Duration(days: 3)),
    isActive: true,
  );

  /// Get all mock profiles as a list
  static List<ProfileData> get allProfiles => [
    professionalProfile,
    socialProfile,
    minimalProfile,
    customProfile,
    enterpriseProfile,
    studentProfile,
  ];

  /// Get profiles by type
  static List<ProfileData> getProfilesByType(ProfileType type) {
    return allProfiles.where((profile) => profile.type == type).toList();
  }

  /// Get random profile for testing
  static ProfileData getRandomProfile() {
    final profiles = allProfiles;
    profiles.shuffle();
    return profiles.first;
  }

  /// Create a profile with random data for stress testing
  static ProfileData createRandomProfile() {
    final names = ['Alice Johnson', 'Bob Smith', 'Carol Davis', 'David Wilson', 'Emma Brown'];
    final companies = ['TechCorp', 'DataSoft', 'CloudSystems', 'InnovateLab', 'StartupXYZ'];
    final titles = ['Software Engineer', 'Product Manager', 'Designer', 'Data Analyst', 'Marketing Lead'];
    final domains = ['gmail.com', 'company.com', 'startup.io', 'tech.co', 'business.net'];

    names.shuffle();
    companies.shuffle();
    titles.shuffle();
    domains.shuffle();

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomName = names.first;
    final firstName = randomName.split(' ').first.toLowerCase();

    return ProfileData(
      id: 'user_random_$timestamp',
      type: ProfileType.values[timestamp % ProfileType.values.length],
      name: randomName,
      title: titles.first,
      company: companies.first,
      email: '$firstName@${domains.first}',
      phone: '+1-555-${(1000 + (timestamp % 9000)).toString().substring(0, 4)}',
      website: 'https://$firstName.${domains.first.split('.').first}.com',
      socialMedia: {
        'linkedin': 'https://linkedin.com/in/$firstName',
        if (timestamp % 2 == 0) 'twitter': 'https://twitter.com/$firstName',
        if (timestamp % 3 == 0) 'github': 'https://github.com/$firstName',
      },
      profileImagePath: '/mock/photos/${firstName}.jpg',
      lastUpdated: DateTime.now().subtract(Duration(days: timestamp % 30)),
      isActive: timestamp % 4 != 0,
    );
  }

  /// Create multiple random profiles for bulk testing
  static List<ProfileData> createRandomProfiles(int count) {
    return List.generate(count, (index) {
      // Add delay to ensure unique timestamps
      Future.delayed(Duration(milliseconds: index));
      return createRandomProfile();
    });
  }

  /// Profile with missing fields for testing validation
  static ProfileData get incompleteProfile => ProfileData(
    id: 'user_incomplete_999',
    type: ProfileType.professional,
    name: 'Incomplete User',
    // Missing title, company, email, phone
    socialMedia: const {},
    lastUpdated: DateTime.now(),
    isActive: false,
  );

  /// Profile with very long data for payload size testing
  static ProfileData get oversizedProfile => ProfileData(
    id: 'user_oversized_with_very_long_identifier_that_exceeds_normal_length_limits',
    type: ProfileType.professional,
    name: 'Dr. Christopher Alexander Montgomery-Fitzpatrick III, PhD, MBA, CTO',
    title: 'Senior Principal Distinguished Software Engineering Architect and Technical Innovation Lead',
    company: 'International Advanced Technology Solutions and Digital Transformation Corporation Limited',
    email: 'christopher.alexander.montgomery-fitzpatrick.the.third@international-advanced-tech-solutions.com',
    phone: '+1-555-9876-ext-12345',
    website: 'https://christopher-alexander-montgomery-fitzpatrick-professional-portfolio-and-consulting.com',
    socialMedia: {
      'linkedin': 'https://linkedin.com/in/christopher-alexander-montgomery-fitzpatrick-iii-phd-mba-cto',
      'twitter': 'https://twitter.com/chris_mont_fitz_tech_leader',
      'github': 'https://github.com/christopher-montgomery-fitzpatrick-senior-architect',
    },
    profileImagePath: '/mock/photos/christopher-alexander-montgomery-fitzpatrick.jpg',
    lastUpdated: DateTime.now(),
    isActive: true,
  );

  /// Get profile by ID
  static ProfileData? getProfileById(String id) {
    try {
      return allProfiles.firstWhere((profile) => profile.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get profiles for privacy level testing
  static Map<String, ProfileData> getPrivacyTestProfiles() {
    return {
      'minimal': minimalProfile,
      'basic': socialProfile,
      'professional': professionalProfile,
      'full': enterpriseProfile,
    };
  }
}

/// Mock received cards for testing receiver functionality
class MockReceivedCards {
  /// Professional card with full contact data
  static ReceivedContact get professionalCard => ReceivedContact(
    id: 'tc_prof123abc',
    receivedAt: DateTime.now().subtract(Duration(minutes: 5)),
    contact: ContactData(
      name: 'Dr. Michael Roberts',
      title: 'Senior Software Architect',
      company: 'TechFlow Inc',
      phone: '+1-555-0199',
      email: 'm.roberts@techflow.com',
      website: 'https://michaelroberts.dev',
      socialMedia: {
        'linkedin': 'michaelroberts-arch',
        'github': 'mroberts-dev',
        'twitter': '@mike_builds'
      },
    ),
  );

  /// Social/creative card with social media focus
  static ReceivedContact get socialCard => ReceivedContact(
    id: 'tc_social456def',
    receivedAt: DateTime.now().subtract(Duration(minutes: 2)),
    contact: ContactData(
      name: 'Emma Wilson',
      title: 'Content Creator',
      phone: '+1-555-0187',
      socialMedia: {
        'instagram': '@emmacreates',
        'tiktok': '@emma_wilson',
        'youtube': 'EmmaCreatesDaily'
      },
    ),
    notes: 'Creating daily content about productivity and lifestyle 🌟',
  );

  /// Minimal card for testing basic contact info
  static ReceivedContact get minimalCard => ReceivedContact(
    id: 'tc_minimal789ghi',
    receivedAt: DateTime.now().subtract(Duration(hours: 2)),
    contact: ContactData(
      name: 'Alex Kim',
      phone: '+1-555-0156',
      email: 'alex.kim.contact@gmail.com',
    ),
  );

  /// Professional card for testing business contact
  static ReceivedContact get businessCard => ReceivedContact(
    id: 'tc_business321xyz',
    receivedAt: DateTime.now().subtract(Duration(seconds: 30)),
    contact: ContactData(
      name: 'Sarah Johnson',
      title: 'UX Designer',
      company: 'Design Studio',
      email: 'sarah@designstudio.com',
      website: 'https://sarahjohnson.design',
      socialMedia: {
        'linkedin': 'sarah-johnson-ux',
        'behance': 'sarahjohnson',
      },
    ),
    notes: 'Met at Design Conference 2024',
  );

  /// Tech professional card
  static ReceivedContact get techCard => ReceivedContact(
    id: 'tc_tech654lmn',
    receivedAt: DateTime.now().subtract(Duration(minutes: 10)),
    contact: ContactData(
      name: 'John Martinez',
      title: 'Data Scientist',
      company: 'Analytics Pro',
      phone: '+1-555-0143',
      email: 'j.martinez@analyticspro.com',
      website: 'https://johnmartinez.data',
      socialMedia: {
        'linkedin': 'john-martinez-data',
        'github': 'jmartinez-data',
      },
    ),
  );

  /// Card with extensive notes
  static ReceivedContact get cardWithNotes => ReceivedContact(
    id: 'tc_notes987qrs',
    receivedAt: DateTime.now().subtract(Duration(hours: 2)),
    contact: ContactData(
      name: 'Lisa Chen',
      title: 'Product Manager',
      company: 'InnovateNow',
      phone: '+1-555-0178',
      email: 'lisa.chen@innovatenow.com',
      website: 'https://lisachen.pm',
      socialMedia: {
        'linkedin': 'lisachen-pm',
        'twitter': '@lisa_builds'
      },
    ),
    notes: 'Met at TechConf 2024. Interested in collaboration on mobile UX project. Product strategist with 8+ years in tech.',
  );

  /// Get all mock cards for comprehensive testing
  static List<ReceivedContact> get allMockCards => [
    professionalCard,
    socialCard,
    businessCard,
    techCard,
    cardWithNotes,
    minimalCard, // Put minimal last as it's oldest
  ];

  /// Get cards by company for testing filtering
  static List<ReceivedContact> getCardsByCompany(String company) {
    return allMockCards.where((card) =>
      card.contact.company?.toLowerCase().contains(company.toLowerCase()) ?? false
    ).toList();
  }

  /// Get cards with social media for testing social features
  static List<ReceivedContact> getCardsWithSocials() {
    return allMockCards.where((card) => card.contact.socialMedia.isNotEmpty).toList();
  }

  /// Generate a random mock card for stress testing
  static ReceivedContact createRandomMockCard() {
    final random = Random();
    final names = ['Alice Smith', 'Bob Johnson', 'Carol Davis', 'David Brown', 'Eve Wilson'];
    final companies = ['TechCorp', 'DesignStudio', 'DataFlow', 'InnovateNow', 'BuildTech'];
    final titles = ['Software Developer', 'Designer', 'Product Manager', 'Data Analyst', 'Engineer'];

    final name = names[random.nextInt(names.length)];
    final company = companies[random.nextInt(companies.length)];
    final title = titles[random.nextInt(titles.length)];
    final id = 'tc_mock_${random.nextInt(999999)}';

    return ReceivedContact(
      id: id,
      receivedAt: DateTime.now().subtract(Duration(minutes: random.nextInt(1440))), // Last 24 hours
      contact: ContactData(
        name: name,
        title: title,
        company: company,
        phone: '+1-555-0${100 + random.nextInt(100)}',
        email: '${name.toLowerCase().replaceAll(' ', '.')}@${company.toLowerCase()}.com',
        website: random.nextBool() ? 'https://${name.toLowerCase().replaceAll(' ', '')}.dev' : null,
        socialMedia: random.nextBool() ? {
          'linkedin': name.toLowerCase().replaceAll(' ', '-'),
          'github': name.toLowerCase().replaceAll(' ', ''),
        } : {},
      ),
      notes: random.nextBool() ? 'Random test note for $name' : null,
    );
  }

  /// Create multiple random cards for bulk testing
  static List<ReceivedContact> createRandomMockCards(int count) {
    return List.generate(count, (index) => createRandomMockCard());
  }
}