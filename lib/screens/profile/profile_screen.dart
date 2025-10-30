import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import 'dart:io';

import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import '../../widgets/profile/profile_basic_fields.dart';
import '../../widgets/profile/social_links_fields.dart';
import '../../widgets/profile/custom_links_fields.dart';
import '../../widgets/profile/card_aesthetics_section.dart';
import '../../core/constants/routes.dart';
import '../../core/models/profile_models.dart';
import '../../core/services/profile_service.dart';

/// Enum for background color picker mode
enum BackgroundMode { solid, gradient }

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _formController;
  late AnimationController _previewController;
  late AnimationController _saveController;

  late Animation<double> _formSlide;
  late Animation<double> _previewScale;
  late Animation<double> _saveScale;

  // Services
  late ProfileService _profileService;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _titleController = TextEditingController();
  final _companyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();

  // Social media controllers
  final Map<String, TextEditingController> _socialControllers = {};
  final Map<String, FocusNode> _socialFocusNodes = {};
  String? _selectedSocialPlatform; // Currently selected social platform for editing

  // Custom link controllers (max 3 links)
  final List<TextEditingController> _customLinkTitleControllers = [];
  final List<TextEditingController> _customLinkUrlControllers = [];
  final List<FocusNode> _customLinkTitleFocusNodes = [];
  final List<FocusNode> _customLinkUrlFocusNodes = [];

  // Focus nodes for basic fields
  final _nameFocus = FocusNode();
  final _titleFocus = FocusNode();
  final _companyFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _websiteFocus = FocusNode();

  // State variables
  File? _profileImage;
  File? _backgroundImage;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false; // Track if form has unsaved changes
  ProfileData? _currentProfile;
  ProfileData? _initialProfile; // Snapshot of profile when loaded for comparison
  ProfileType _selectedProfileType = ProfileType.personal;
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> _recentCombinations = [];

  // Helper getters for current card aesthetics
  CardAesthetics get _currentAesthetics => _currentProfile?.cardAesthetics ?? CardAesthetics.defaultForType(_selectedProfileType);
  double get _blurLevel => _currentAesthetics.blurLevel;
  Color get _borderColor => _currentAesthetics.borderColor;
  Color? get _backgroundColor => _currentAesthetics.backgroundColor;
  Color get _primaryColor => _currentAesthetics.primaryColor;
  Color get _secondaryColor => _currentAesthetics.secondaryColor;

  set _backgroundColor(Color? color) {
    _updateCardAesthetics(backgroundColor: color);
  }

  set _borderColor(Color color) {
    _updateCardAesthetics(borderColor: color);
  }

  // Preset color combinations (displayed before recent combinations)
  // These are aesthetic presets, not stored in profile data
  final List<Map<String, dynamic>> _presetCombinations = [
    {
      'name': 'Professional',
      'primary': AppColors.primaryAction,
      'secondary': AppColors.secondaryAction,
    },
    {
      'name': 'Creative',
      'primary': AppColors.highlight,
      'secondary': AppColors.primaryAction,
    },
    {
      'name': 'Minimal',
      'primary': AppColors.textPrimary,
      'secondary': AppColors.textSecondary,
    },
    {
      'name': 'Modern',
      'primary': const Color(0xFF6C63FF),
      'secondary': const Color(0xFF00BCD4),
    },
  ];
  @override
  void initState() {
    super.initState();
    _profileService = ProfileService();
    _initAnimations();
    _initServices();
    _initTextControllerListeners();
  }

  Future<void> _initServices() async {
    await _profileService.initialize();
    _loadCurrentProfile();
    _profileService.addListener(_onProfileServiceChanged);
  }

  void _onProfileServiceChanged() {
    if (mounted) {
      _loadCurrentProfile();
    }
  }

  void _loadCurrentProfile() {
    final activeProfile = _profileService.activeProfile;
    if (activeProfile != null) {
      _currentProfile = activeProfile;
      _initialProfile = activeProfile.copyWith(); // Store initial snapshot for comparison
      _selectedProfileType = activeProfile.type;
      _populateFormFromProfile(activeProfile);
      _setupSocialControllers();
      setState(() {
        _hasUnsavedChanges = false; // Reset when loading profile
      });
    }
  }

  void _populateFormFromProfile(ProfileData profile) {
    _nameController.text = profile.name;
    _titleController.text = profile.title ?? '';
    _companyController.text = profile.company ?? '';
    _phoneController.text = profile.phone ?? '';
    _emailController.text = profile.email ?? '';
    _websiteController.text = profile.website ?? '';

    if (profile.profileImagePath != null) {
      _profileImage = File(profile.profileImagePath!);
    } else {
      _profileImage = null;
    }

    // Load background image from CardAesthetics
    if (profile.cardAesthetics.backgroundImagePath != null) {
      _backgroundImage = File(profile.cardAesthetics.backgroundImagePath!);
    } else {
      _backgroundImage = null;
    }

    // Populate social media fields
    for (final entry in profile.socialMedia.entries) {
      final controller = _socialControllers[entry.key];
      if (controller != null) {
        controller.text = entry.value;
      }
    }
  }

  void _setupSocialControllers() {
    // Clear existing controllers and focus nodes
    for (final controller in _socialControllers.values) {
      controller.dispose();
    }
    for (final focusNode in _socialFocusNodes.values) {
      focusNode.dispose();
    }
    _socialControllers.clear();
    _socialFocusNodes.clear();

    // Create controllers for available social platforms
    final availableSocials = ProfileData.getAvailableSocials(_selectedProfileType);
    for (final social in availableSocials) {
      _socialControllers[social] = TextEditingController();
      _socialFocusNodes[social] = FocusNode();

      // Add listeners for change tracking and preview updates
      _socialControllers[social]!.addListener(_onFormChanged);
    }

    // Populate with existing data
    if (_currentProfile != null) {
      for (final entry in _currentProfile!.socialMedia.entries) {
        final controller = _socialControllers[entry.key];
        if (controller != null) {
          controller.text = entry.value;
        }
      }
    }
  }

  void _initAnimations() {
    _formController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _previewController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _saveController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _formSlide = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _formController,
      curve: Curves.easeOutCubic,
    ));

    _previewScale = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _previewController,
      curve: Curves.easeOutBack,
    ));

    _saveScale = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _saveController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _formController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _previewController.forward();
    });
  }

  void _initTextControllerListeners() {
    // Add listeners for real-time preview updates and change tracking
    _nameController.addListener(_onFormChanged);
    _titleController.addListener(_onFormChanged);
    _companyController.addListener(_onFormChanged);
    _phoneController.addListener(_onFormChanged);
    _emailController.addListener(_onFormChanged);
    _websiteController.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    setState(() {
      _hasUnsavedChanges = _hasActualChanges(); // Only mark if actual changes exist
    });
  }

  /// Check if current form state differs from initial profile
  bool _hasActualChanges() {
    if (_initialProfile == null || _currentProfile == null) return false;

    // Check basic fields
    if (_nameController.text.trim() != _initialProfile!.name) return true;
    if (_titleController.text.trim() != (_initialProfile!.title ?? '')) return true;
    if (_companyController.text.trim() != (_initialProfile!.company ?? '')) return true;
    if (_phoneController.text.trim() != (_initialProfile!.phone ?? '')) return true;
    if (_emailController.text.trim() != (_initialProfile!.email ?? '')) return true;
    if (_websiteController.text.trim() != (_initialProfile!.website ?? '')) return true;

    // Check images
    if (_profileImage?.path != _initialProfile!.profileImagePath) return true;
    if (_backgroundImage?.path != _initialProfile!.cardAesthetics.backgroundImagePath) return true;

    // Check card aesthetics
    final initialAesthetics = _initialProfile!.cardAesthetics;
    final currentAesthetics = _currentAesthetics;
    if (currentAesthetics.blurLevel != initialAesthetics.blurLevel) return true;
    if (currentAesthetics.borderColor.toARGB32() != initialAesthetics.borderColor.toARGB32()) return true;
    if ((currentAesthetics.backgroundColor?.toARGB32() ?? 0) != (initialAesthetics.backgroundColor?.toARGB32() ?? 0)) return true;

    // Check social media
    for (final entry in _socialControllers.entries) {
      final currentValue = entry.value.text.trim();
      final initialValue = _initialProfile!.socialMedia[entry.key] ?? '';
      if (currentValue != initialValue) return true;
    }

    return false;
  }

  void _updatePreview() {
    setState(() {}); // Trigger rebuild for live preview
  }

  /// Update card aesthetics and trigger preview update
  void _updateCardAesthetics({
    Color? primaryColor,
    Color? secondaryColor,
    Color? borderColor,
    Color? backgroundColor,
    bool clearBackgroundColor = false,
    double? blurLevel,
    String? backgroundImagePath,
    bool clearBackgroundImage = false,
  }) {
    if (_currentProfile == null) return;

    // Handle explicit null values
    final CardAesthetics updatedAesthetics;
    if (clearBackgroundColor || clearBackgroundImage) {
      updatedAesthetics = CardAesthetics(
        primaryColor: primaryColor ?? _currentProfile!.cardAesthetics.primaryColor,
        secondaryColor: secondaryColor ?? _currentProfile!.cardAesthetics.secondaryColor,
        borderColor: borderColor ?? _currentProfile!.cardAesthetics.borderColor,
        backgroundColor: clearBackgroundColor ? null : (backgroundColor ?? _currentProfile!.cardAesthetics.backgroundColor),
        blurLevel: blurLevel ?? _currentProfile!.cardAesthetics.blurLevel,
        backgroundImagePath: clearBackgroundImage ? null : (backgroundImagePath ?? _currentProfile!.cardAesthetics.backgroundImagePath),
      );
    } else {
      updatedAesthetics = _currentProfile!.cardAesthetics.copyWith(
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
        borderColor: borderColor,
        backgroundColor: backgroundColor,
        blurLevel: blurLevel,
        backgroundImagePath: backgroundImagePath,
      );
    }

    setState(() {
      _currentProfile = _currentProfile!.copyWith(
        cardAesthetics: updatedAesthetics,
      );
      _hasUnsavedChanges = _hasActualChanges(); // Check for changes
    });
  }

  Future<void> _pickImage(ImageSource source, {bool isBackground = false}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 100, // Pick at full quality, will compress after crop
      );

      if (image != null) {
        // Crop the image
        final CroppedFile? croppedFile = await ImageCropper().cropImage(
          sourcePath: image.path,
          compressFormat: ImageCompressFormat.jpg,
          compressQuality: isBackground ? 90 : 80,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: isBackground ? 'Crop Background' : 'Crop Profile Photo',
              toolbarColor: AppColors.primaryAction,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: isBackground
                  ? CropAspectRatioPreset.ratio3x2
                  : CropAspectRatioPreset.square,
              lockAspectRatio: true,
              aspectRatioPresets: [
                isBackground
                    ? CropAspectRatioPreset.ratio3x2
                    : CropAspectRatioPreset.square,
              ],
            ),
            IOSUiSettings(
              title: isBackground ? 'Crop Background' : 'Crop Profile Photo',
              aspectRatioLockEnabled: true,
              resetAspectRatioEnabled: false,
              aspectRatioPickerButtonHidden: true,
            ),
          ],
        );

        if (croppedFile != null) {
          setState(() {
            if (isBackground) {
              _backgroundImage = File(croppedFile.path);
            } else {
              _profileImage = File(croppedFile.path);
            }
            _hasUnsavedChanges = _hasActualChanges(); // Check for changes
          });
          HapticFeedback.lightImpact();
        }
      }
    } catch (e) {
      // Handle error
      print('Error picking/cropping image: $e');
    }
  }

  void _showImagePicker({bool isBackground = false}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: _buildImagePickerModal(isBackground: isBackground),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.mediumImpact();
    _saveController.forward().then((_) => _saveController.reverse());

    setState(() => _isSaving = true);

    await _saveCurrentProfile();

    if (mounted) {
      setState(() {
        _isSaving = false;
        _hasUnsavedChanges = false; // Reset unsaved changes flag
      });

      // Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.success.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(CupertinoIcons.check_mark_circled_solid, color: AppColors.success),
                    SizedBox(width: 12),
                    Expanded(child: Text('Profile saved successfully!')),
                  ],
                ),
              ),
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _saveCurrentProfile() async {
    if (_currentProfile == null) return;

    // Collect social media data
    final socialMediaData = <String, String>{};
    for (final entry in _socialControllers.entries) {
      final value = entry.value.text.trim();
      if (value.isNotEmpty) {
        socialMediaData[entry.key] = value;
      }
    }

    // Collect custom links data (up to 3 links with title and URL)
    final customLinksList = <CustomLink>[];
    for (int i = 0; i < _customLinkTitleControllers.length; i++) {
      final title = _customLinkTitleControllers[i].text.trim();
      final url = _customLinkUrlControllers[i].text.trim();

      // Only add valid links (both title and URL must be non-empty)
      if (title.isNotEmpty && url.isNotEmpty) {
        customLinksList.add(CustomLink(title: title, url: url));
      }
    }

    // Create updated profile with CardAesthetics
    final updatedAesthetics = _currentAesthetics.copyWith(
      backgroundImagePath: _backgroundImage?.path,
      clearBackgroundImagePath: _backgroundImage == null,
    );

    final updatedProfile = _currentProfile!.copyWith(
      name: _nameController.text.trim(),
      title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
      company: _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
      socialMedia: socialMediaData,
      customLinks: customLinksList,
      profileImagePath: _profileImage?.path,
      cardAesthetics: updatedAesthetics,
    );

    // Regenerate NFC cache when profile data changes for instant sharing (includes dual-payload)
    final profileWithFreshCache = updatedProfile.regenerateDualPayloadCache();
    await _profileService.updateProfile(profileWithFreshCache);

    // Save color combination after successful profile save
    _saveColorCombination();
  }

  // Launch methods for ProfileCardPreview interactions
  Future<void> _launchEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      Uri uri;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        uri = Uri.parse('https://$url');
      } else {
        uri = Uri.parse(url);
      }

      // Skip canLaunchUrl check - it's unreliable and may return false even when launchUrl works
      // Just try to launch directly and handle errors
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      // Show error only if launchUrl actually fails
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link: $url'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _launchSocialMedia(String platform, String url) async {
    try {
      // 1. Try to open native app first
      final appUri = _getSocialAppUri(platform, url);
      if (appUri != null && await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
        return;
      }

      // 2. Fall back to web URL
      String finalUrl = url;
      if (!url.startsWith('http')) {
        finalUrl = _getSocialUrl(platform, url);
      }
      await _launchUrl(finalUrl);
    } catch (e) {
      // If all fails, show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open $platform link'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Get native app URI for social platform
  /// Returns null if platform doesn't support app schemes
  Uri? _getSocialAppUri(String platform, String username) {
    final cleanUsername = username.startsWith('@')
      ? username.substring(1)
      : username;

    // Skip if already a full URL
    if (username.startsWith('http')) return null;

    try {
      switch (platform.toLowerCase()) {
        case 'instagram':
          return Uri.parse('instagram://user?username=$cleanUsername');
        case 'twitter':
        case 'x':
          return Uri.parse('twitter://user?screen_name=$cleanUsername');
        case 'linkedin':
          return Uri.parse('linkedin://profile/$cleanUsername');
        case 'github':
          return Uri.parse('github://$cleanUsername');
        case 'tiktok':
          return Uri.parse('tiktok://user?username=$cleanUsername');
        case 'youtube':
          return Uri.parse('youtube://user/$cleanUsername');
        case 'facebook':
          return Uri.parse('fb://profile/$cleanUsername');
        case 'snapchat':
          return Uri.parse('snapchat://add/$cleanUsername');
        case 'behance':
        case 'dribbble':
        case 'discord':
          // These don't have reliable user schemes
          return null;
        default:
          return null;
      }
    } catch (e) {
      return null;
    }
  }

  String _getSocialUrl(String platform, String username) {
    final cleanUsername = username.startsWith('@') ? username.substring(1) : username;
    switch (platform.toLowerCase()) {
      case 'linkedin':
        return 'https://linkedin.com/in/$cleanUsername';
      case 'twitter':
      case 'x':
        return 'https://twitter.com/$cleanUsername';
      case 'github':
        return 'https://github.com/$cleanUsername';
      case 'instagram':
        return 'https://instagram.com/$cleanUsername';
      case 'behance':
        return 'https://behance.net/$cleanUsername';
      case 'dribbble':
        return 'https://dribbble.com/$cleanUsername';
      case 'tiktok':
        return 'https://tiktok.com/@$cleanUsername';
      case 'youtube':
        return 'https://youtube.com/@$cleanUsername';
      default:
        return username;
    }
  }

  @override
  void dispose() {
    // Remove listeners
    _profileService.removeListener(_onProfileServiceChanged);

    // Dispose controllers
    _formController.dispose();
    _previewController.dispose();
    _saveController.dispose();

    // Dispose text controllers
    _nameController.dispose();
    _titleController.dispose();
    _companyController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();

    // Dispose social media controllers and focus nodes
    for (final controller in _socialControllers.values) {
      controller.dispose();
    }
    for (final focusNode in _socialFocusNodes.values) {
      focusNode.dispose();
    }

    // Dispose custom link controllers and focus nodes
    for (final controller in _customLinkTitleControllers) {
      controller.dispose();
    }
    for (final controller in _customLinkUrlControllers) {
      controller.dispose();
    }
    for (final focusNode in _customLinkTitleFocusNodes) {
      focusNode.dispose();
    }
    for (final focusNode in _customLinkUrlFocusNodes) {
      focusNode.dispose();
    }

    // Dispose basic field focus nodes
    _nameFocus.dispose();
    _titleFocus.dispose();
    _companyFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _websiteFocus.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      key: const Key('profile_scaffold'),
      body: Stack(
        children: [
          // Background gradient (full screen behind everything)
          Positioned.fill(
            child: Container(
              key: const Key('profile_main_container'),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryBackground,
                    AppColors.surfaceDark,
                  ],
                ),
              ),
            ),
          ),
          // Content scrolls from top
          SingleChildScrollView(
            key: const Key('profile_scroll_view'),
            padding: EdgeInsets.only(
              top: statusBarHeight + 80 + 16 + 8, // App bar + horizontal padding + top spacing
              left: 16,
              right: 16,
              bottom: 100, // Original bottom spacing
            ),
            child: Form(
              key: _formKey,
              child: Column(
                key: const Key('profile_form_column'),
                children: [
                  _buildLivePreview(),
                  const SizedBox(key: Key('profile_preview_spacing'), height: 24),
                  _buildBlurSlider(),
                  const SizedBox(key: Key('profile_blur_spacing'), height: 24),
                  CardAestheticsSection(
                    cardAesthetics: _currentProfile?.cardAesthetics ?? const CardAesthetics(),
                    recentCombinations: _recentCombinations,
                    backgroundImage: _backgroundImage,
                    onAestheticsChanged: (aesthetics) {
                      setState(() {
                        _currentProfile = _currentProfile!.copyWith(cardAesthetics: aesthetics);
                        _hasUnsavedChanges = _hasActualChanges();
                      });
                    },
                    onAddRecentCombination: _addToRecentCombinations,
                    onBackgroundImageTap: () => _showImagePicker(isBackground: true),
                  ),
                  const SizedBox(key: Key('profile_template_spacing'), height: 24),
                  if (_profileService.multipleProfilesEnabled) ...[
                    _buildProfileSelector(),
                    const SizedBox(key: Key('profile_selector_spacing'), height: 24),
                  ],
                  _buildFormSection(),
                  const SizedBox(key: Key('profile_form_spacing'), height: 32),
                  _buildSaveButton(),
                ],
              ),
            ),
          ),
          // App bar overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildGlassAppBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassAppBar() {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Padding(
      padding: EdgeInsets.only(
        top: statusBarHeight + 16,
        left: 16,
        right: 16,
      ),
      child: SizedBox(
        key: const Key('profile_appbar_container'),
        height: 64,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              key: const Key('profile_appbar_content_container'),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                key: const Key('profile_appbar_row'),
                children: [
                  // Clear All button
                  Material(
                    key: const Key('profile_appbar_clear_button_material'),
                    color: Colors.transparent,
                    child: InkWell(
                      key: const Key('profile_appbar_clear_button_inkwell'),
                      onTap: _showClearContentDialog,
                      borderRadius: BorderRadius.circular(12),
                      child: const SizedBox(
                        key: Key('profile_appbar_clear_button_container'),
                        width: 48,
                        height: 48,
                        child: Icon(
                          key: Key('profile_appbar_clear_icon'),
                          CupertinoIcons.delete,
                          color: AppColors.error,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    key: const Key('profile_appbar_title_section'),
                    child: Text(
                      key: const Key('profile_appbar_title_text'),
                      'Profile Setup',
                      style: AppTextStyles.h3.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Material(
                    key: const Key('profile_appbar_settings_button_material'),
                    color: Colors.transparent,
                    child: InkWell(
                      key: const Key('profile_appbar_settings_button_inkwell'),
                      onTap: _openSettings,
                      borderRadius: BorderRadius.circular(12),
                      child: const SizedBox(
                        key: Key('profile_appbar_settings_button_container'),
                        width: 48,
                        height: 48,
                        child: Icon(
                          key: Key('profile_appbar_settings_icon'),
                          CupertinoIcons.settings,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildImagePickerModal({bool isBackground = false}) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.25),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isBackground ? 'Choose Background Image' : 'Choose Profile Photo',
                  style: AppTextStyles.h3.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildImagePickerOption(
                        icon: CupertinoIcons.camera,
                        title: 'Camera',
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.camera, isBackground: isBackground);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildImagePickerOption(
                        icon: CupertinoIcons.photo,
                        title: 'Gallery',
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.gallery, isBackground: isBackground);
                        },
                      ),
                    ),
                  ],
                ),
                if (isBackground && _backgroundImage != null) ...[
                  const SizedBox(height: 20),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _backgroundImage = null;
                        });
                        // Update card aesthetics to clear backgroundImagePath
                        _updateCardAesthetics(clearBackgroundImage: true);
                        HapticFeedback.lightImpact();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.error.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              CupertinoIcons.trash,
                              color: AppColors.error,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Remove Background',
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePickerOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: AppColors.primaryAction,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSelector() {
    return AnimatedBuilder(
      animation: _formController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _formSlide.value * 50),
          child: Opacity(
            opacity: 1.0 - _formSlide.value,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile Type',
                  style: AppTextStyles.h3.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: ProfileType.values.map((profileType) {
                    final profile = _profileService.getProfileByType(profileType);
                    final isSelected = profile?.id == _currentProfile?.id;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: profileType != ProfileType.values.last ? 12 : 0,
                        ),
                        child: _buildProfileTypeCard(profileType, isSelected),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileTypeCard(ProfileType profileType, bool isSelected) {
    final profile = _profileService.getProfileByType(profileType);

    return GestureDetector(
      onTap: () => _switchToProfileType(profileType),
      child: SizedBox(
        height: 120,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryAction
                      : Colors.white.withOpacity(0.2),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primaryAction.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getProfileTypeIcon(profileType),
                      color: isSelected
                          ? AppColors.primaryAction
                          : AppColors.textSecondary,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      profileType.label,
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppColors.primaryAction
                            : AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile?.name.isNotEmpty == true ? profile!.name : profileType.label,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        color: AppColors.textTertiary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getProfileTypeIcon(ProfileType type) {
    switch (type) {
      case ProfileType.personal:
        return CupertinoIcons.person;
      case ProfileType.professional:
        return CupertinoIcons.briefcase;
      case ProfileType.custom:
        return CupertinoIcons.slider_horizontal_3;
    }
  }

  void _switchToProfileType(ProfileType profileType) async {
    final profile = _profileService.getProfileByType(profileType);
    if (profile == null || profile.id == _currentProfile?.id) return;

    // Save current profile before switching
    if (_currentProfile != null) {
      await _saveCurrentProfile();
    }

    await _profileService.setActiveProfile(profile.id);
    HapticFeedback.lightImpact();
  }


  Widget _buildFormSection() {
    if (_currentProfile == null) return const SizedBox();

    return AnimatedBuilder(
      animation: _formController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _formSlide.value * 100),
          child: Opacity(
            opacity: 1.0 - _formSlide.value,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile Information',
                  style: AppTextStyles.h3.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                ProfileBasicFields(
                  profileType: _selectedProfileType,
                  nameController: _nameController,
                  titleController: _titleController,
                  companyController: _companyController,
                  phoneController: _phoneController,
                  emailController: _emailController,
                  websiteController: _websiteController,
                  nameFocus: _nameFocus,
                  titleFocus: _titleFocus,
                  companyFocus: _companyFocus,
                  phoneFocus: _phoneFocus,
                  emailFocus: _emailFocus,
                  websiteFocus: _websiteFocus,
                  getNextFocus: _getNextFocus,
                  onFormChanged: _onFormChanged,
                ),
                const SizedBox(height: 24),
                SocialLinksFields(
                  profileType: _selectedProfileType,
                  socialControllers: _socialControllers,
                  socialFocusNodes: _socialFocusNodes,
                  onFormChanged: _onFormChanged,
                ),
                const SizedBox(height: 24),
                CustomLinksFields(
                  currentProfile: _currentProfile,
                  customLinkTitleControllers: _customLinkTitleControllers,
                  customLinkUrlControllers: _customLinkUrlControllers,
                  customLinkTitleFocusNodes: _customLinkTitleFocusNodes,
                  customLinkUrlFocusNodes: _customLinkUrlFocusNodes,
                  onFormChanged: _onFormChanged,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<String> _getAvailableSocialPlatforms() {
    return ProfileData.getAvailableSocials(_selectedProfileType);
  }

  FocusNode? _getNextFocus(String currentField) {
    // This is a simplified version - you might want to implement proper focus chain
    switch (currentField) {
      case 'name':
        return _selectedProfileType == ProfileType.professional || _selectedProfileType == ProfileType.custom
            ? _titleFocus : _phoneFocus;
      case 'title':
        return _selectedProfileType == ProfileType.professional ? _companyFocus : _phoneFocus;
      case 'company':
        return _phoneFocus;
      case 'phone':
        return _emailFocus;
      case 'email':
        return _selectedProfileType == ProfileType.professional || _selectedProfileType == ProfileType.custom
            ? _websiteFocus : null;
      case 'website':
        final socials = _getAvailableSocialPlatforms();
        return socials.isNotEmpty ? _socialFocusNodes[socials.first] : null;
      default:
        return null;
    }
  }


  /// Add a color combination to recent combinations list
  /// Supports both full combinations (primary, secondary, background, border)
  /// and partial combinations (just background/border)
  void _addToRecentCombinations(Map<String, dynamic> combination) {
    // Remove if already exists (check by primary/secondary OR background/border)
    _recentCombinations.removeWhere((c) {
      // Check primary+secondary match
      if (combination['primary'] != null && combination['secondary'] != null) {
        return (c['primary'] as Color?)?.toARGB32() == (combination['primary'] as Color?)?.toARGB32() &&
               (c['secondary'] as Color?)?.toARGB32() == (combination['secondary'] as Color?)?.toARGB32();
      }
      // Check background+border match
      return (c['background'] as Color?)?.toARGB32() == (combination['background'] as Color?)?.toARGB32() &&
             (c['border'] as Color?)?.toARGB32() == (combination['border'] as Color?)?.toARGB32();
    });

    // Add to beginning
    _recentCombinations.insert(0, combination);

    // Keep only first 3
    if (_recentCombinations.length > 3) {
      _recentCombinations = _recentCombinations.take(3).toList();
    }
  }

  void _saveColorCombination() {
    // Save combination if either background or border is customized
    if (_backgroundColor != null || _borderColor != Colors.white) {
      final combination = {
        'primary': _primaryColor,
        'secondary': _secondaryColor,
        'background': _backgroundColor,
        'border': _borderColor,
      };
      _addToRecentCombinations(combination);
    }
  }

  Widget _buildBlurSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Glassmorphic Blur',
              style: AppTextStyles.h3.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${_blurLevel.toStringAsFixed(1)}px',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.primaryAction,
            inactiveTrackColor: AppColors.textSecondary.withOpacity(0.3),
            thumbColor: AppColors.primaryAction,
            overlayColor: AppColors.primaryAction.withOpacity(0.2),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: _blurLevel,
            min: 0,
            max: 18,
            divisions: 36,
            onChanged: (value) {
              _updateCardAesthetics(blurLevel: value);
              HapticFeedback.lightImpact();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLivePreview() {
    return AnimatedBuilder(
      animation: _previewController,
      builder: (context, child) {
        return Transform.scale(
          scale: _previewScale.value,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Live Preview',
                style: AppTextStyles.h3.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _buildContactCard(),
            ],
          ),
        );
      },
    );
  }

  /// Build preview ProfileData from current form state
  ProfileData _buildPreviewProfile() {
    final socialMediaData = <String, String>{};
    for (final entry in _socialControllers.entries) {
      final value = entry.value.text.trim();
      if (value.isNotEmpty) {
        socialMediaData[entry.key] = value;
      }
    }

    final updatedAesthetics = _currentAesthetics.copyWith(
      backgroundImagePath: _backgroundImage?.path,
      backgroundColor: _backgroundColor,
      borderColor: _borderColor,
      blurLevel: _blurLevel,
    );

    if (_currentProfile == null) {
      return ProfileData(
        id: 'preview',
        type: ProfileType.personal,
        name: _nameController.text.trim().isEmpty ? 'Your Name' : _nameController.text.trim(),
        title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
        company: _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
        socialMedia: socialMediaData,
        profileImagePath: _profileImage?.path,
        cardAesthetics: updatedAesthetics,
        lastUpdated: DateTime.now(),
      );
    }

    return _currentProfile!.copyWith(
      name: _nameController.text.trim().isEmpty ? 'Your Name' : _nameController.text.trim(),
      title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
      company: _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
      socialMedia: socialMediaData,
      profileImagePath: _profileImage?.path,
      cardAesthetics: updatedAesthetics,
    );
  }

  Widget _buildContactCard() {
    final previewProfile = _buildPreviewProfile();

    return Center(
      child: ProfileCardPreview(
        profile: previewProfile,
        width: double.infinity,
        height: 200,
        borderRadius: 20,
        onProfileImageTap: () => _showImagePicker(isBackground: false),
        onEmailTap: previewProfile.email != null && previewProfile.email!.isNotEmpty
            ? () => _launchEmail(previewProfile.email!)
            : null,
        onPhoneTap: previewProfile.phone != null && previewProfile.phone!.isNotEmpty
            ? () => _launchPhone(previewProfile.phone!)
            : null,
        onWebsiteTap: previewProfile.website != null && previewProfile.website!.isNotEmpty
            ? () => _launchUrl(previewProfile.website!)
            : null,
        onSocialTap: (platform, url) => _launchSocialMedia(platform, url),
        onCustomLinkTap: (title, url) => _launchUrl(url),
      ),
    );
  }

  Widget _buildSaveButton() {
    // Use secondary gradient when there are unsaved changes, primary gradient when clean
    final buttonGradient = _hasUnsavedChanges
        ? AppColors.secondaryGradient
        : AppColors.primaryGradient;

    return AnimatedBuilder(
      animation: _saveController,
      builder: (context, child) {
        return Transform.scale(
          scale: _saveScale.value,
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isSaving ? null : _saveProfile,
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    gradient: buttonGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (_hasUnsavedChanges
                            ? AppColors.secondaryAction
                            : AppColors.primaryAction).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                      const BoxShadow(
                        color: AppColors.shadowLight,
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Save Profile',
                                style: AppTextStyles.buttonLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(
                                CupertinoIcons.floppy_disk,
                                size: 20,
                                color: Colors.white,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openSettings() {
    HapticFeedback.lightImpact();
    context.go(AppRoutes.settings);
  }

  void _showClearContentDialog() {
    final dialogContext = context;

    GlassmorphicDialog.show(
      context: context,
      icon: const Icon(
        CupertinoIcons.exclamationmark_triangle_fill,
        color: AppColors.error,
        size: 48,
      ),
      title: 'Clear All Content?',
      content: 'This will clear all form fields, profile image, and background image. This action cannot be undone.',
      isDangerous: true,
      actions: [
        DialogAction.secondary(
          text: 'Cancel',
          onPressed: () {
            Navigator.of(dialogContext, rootNavigator: true).pop();
          },
        ),
        DialogAction.primary(
          text: 'Clear All',
          isDestructive: true,
          onPressed: () {
            Navigator.of(dialogContext, rootNavigator: true).pop();
            _clearAllContent();
          },
        ),
      ],
    );
  }

  void _clearAllContent() {
    setState(() {
      // Clear all text controllers
      _nameController.clear();
      _titleController.clear();
      _companyController.clear();
      _phoneController.clear();
      _emailController.clear();
      _websiteController.clear();

      // Clear social media controllers
      for (final controller in _socialControllers.values) {
        controller.clear();
      }

      // Clear images
      _profileImage = null;
      _backgroundImage = null;
    });

    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.error.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Row(
                children: [
                  Icon(CupertinoIcons.exclamationmark_circle_fill, color: AppColors.error),
                  SizedBox(width: 12),
                  Expanded(child: Text('All content cleared')),
                ],
              ),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// Template models

// Helper class for focus state listening
class _FocusNotifier extends ValueNotifier<bool> {
  final FocusNode focusNode;

  _FocusNotifier(this.focusNode) : super(focusNode.hasFocus) {
    focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    value = focusNode.hasFocus;
  }

  @override
  void dispose() {
    focusNode.removeListener(_onFocusChange);
    super.dispose();
  }
}