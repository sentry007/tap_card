import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import 'dart:io';

import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import '../../core/constants/routes.dart';
import '../../core/models/profile_models.dart';
import '../../core/services/profile_service.dart';

/// Enum for background color picker mode
enum BackgroundMode { solid, gradient }

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

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
  List<Map<String, Color?>> _recentCombinations = [];

  // Helper getters for current card aesthetics
  CardAesthetics get _currentAesthetics => _currentProfile?.cardAesthetics ?? CardAesthetics.defaultForType(_selectedProfileType);
  double get _blurLevel => _currentAesthetics.blurLevel;
  Color get _borderColor => _currentAesthetics.borderColor;
  Color? get _backgroundColor => _currentAesthetics.backgroundColor;
  Color get _primaryColor => _currentAesthetics.primaryColor;
  Color get _secondaryColor => _currentAesthetics.secondaryColor;

  // Template index getter (for compatibility)
  int get _selectedTemplate => _currentAesthetics.templateIndex;

  // Template setters (update CardAesthetics)
  set _selectedTemplate(int index) {
    if (index >= 0 && index < _templates.length) {
      final template = _templates[index];
      _updateCardAesthetics(
        templateIndex: index,
        primaryColor: template.primaryColor,
        secondaryColor: template.secondaryColor,
      );
    }
  }

  set _backgroundColor(Color? color) {
    _updateCardAesthetics(backgroundColor: color);
  }

  set _borderColor(Color color) {
    _updateCardAesthetics(borderColor: color);
  }

  // Templates
  final List<ContactTemplate> _templates = [
    ContactTemplate(
      name: 'Professional',
      primaryColor: AppColors.primaryAction,
      secondaryColor: AppColors.secondaryAction,
      backgroundStyle: TemplateBackground.gradient,
    ),
    ContactTemplate(
      name: 'Creative',
      primaryColor: AppColors.highlight,
      secondaryColor: AppColors.primaryAction,
      backgroundStyle: TemplateBackground.pattern,
    ),
    ContactTemplate(
      name: 'Minimal',
      primaryColor: AppColors.textPrimary,
      secondaryColor: AppColors.textSecondary,
      backgroundStyle: TemplateBackground.solid,
    ),
    ContactTemplate(
      name: 'Modern',
      primaryColor: const Color(0xFF6C63FF),
      secondaryColor: const Color(0xFF00BCD4),
      backgroundStyle: TemplateBackground.gradient,
    ),
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
    if (currentAesthetics.templateIndex != initialAesthetics.templateIndex) return true;
    if (currentAesthetics.blurLevel != initialAesthetics.blurLevel) return true;
    if (currentAesthetics.borderColor.value != initialAesthetics.borderColor.value) return true;
    if ((currentAesthetics.backgroundColor?.value ?? 0) != (initialAesthetics.backgroundColor?.value ?? 0)) return true;

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
    int? templateIndex,
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
        templateIndex: templateIndex ?? _currentProfile!.cardAesthetics.templateIndex,
        primaryColor: primaryColor ?? _currentProfile!.cardAesthetics.primaryColor,
        secondaryColor: secondaryColor ?? _currentProfile!.cardAesthetics.secondaryColor,
        borderColor: borderColor ?? _currentProfile!.cardAesthetics.borderColor,
        backgroundColor: clearBackgroundColor ? null : (backgroundColor ?? _currentProfile!.cardAesthetics.backgroundColor),
        blurLevel: blurLevel ?? _currentProfile!.cardAesthetics.blurLevel,
        backgroundImagePath: clearBackgroundImage ? null : (backgroundImagePath ?? _currentProfile!.cardAesthetics.backgroundImagePath),
      );
    } else {
      updatedAesthetics = _currentProfile!.cardAesthetics.copyWith(
        templateIndex: templateIndex,
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
          content: Text('Profile saved successfully!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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

    // Create updated profile with CardAesthetics
    final updatedAesthetics = _currentAesthetics.copyWith(
      backgroundImagePath: _backgroundImage?.path,
    );

    final updatedProfile = _currentProfile!.copyWith(
      name: _nameController.text.trim(),
      title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
      company: _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
      socialMedia: socialMediaData,
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
    Uri uri;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      uri = Uri.parse('https://$url');
    } else {
      uri = Uri.parse(url);
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchSocialMedia(String platform, String url) async {
    String finalUrl = url;
    if (!url.startsWith('http')) {
      finalUrl = _getSocialUrl(platform, url);
    }
    await _launchUrl(finalUrl);
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
                  _buildTemplateSelector(),
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
                      child: Container(
                        key: const Key('profile_appbar_clear_button_container'),
                        width: 48,
                        height: 48,
                        child: const Icon(
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
                      child: Container(
                        key: const Key('profile_appbar_settings_button_container'),
                        width: 48,
                        height: 48,
                        child: const Icon(
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
                            Icon(
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
      child: Container(
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
                ..._buildBasicFields(),
                if (_getAvailableSocialPlatforms().isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Social Media',
                    style: AppTextStyles.h3.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._buildSocialFields(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildBasicFields() {
    final fields = <Widget>[];
    final profileType = _selectedProfileType;

    // Name field (always required)
    fields.addAll([
      _buildGlassTextField(
        controller: _nameController,
        focusNode: _nameFocus,
        nextFocusNode: _getNextFocus('name'),
        label: 'Full Name',
        icon: CupertinoIcons.person,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Name is required';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
    ]);

    // Title field for Professional and Custom
    if (profileType == ProfileType.professional || profileType == ProfileType.custom) {
      fields.addAll([
        _buildGlassTextField(
          controller: _titleController,
          focusNode: _titleFocus,
          nextFocusNode: _getNextFocus('title'),
          label: 'Title/Position',
          icon: CupertinoIcons.bag,
        ),
        const SizedBox(height: 16),
      ]);
    }

    // Company field for Professional
    if (profileType == ProfileType.professional) {
      fields.addAll([
        _buildGlassTextField(
          controller: _companyController,
          focusNode: _companyFocus,
          nextFocusNode: _getNextFocus('company'),
          label: 'Company',
          icon: CupertinoIcons.building_2_fill,
        ),
        const SizedBox(height: 16),
      ]);
    }

    // Phone field (all profiles)
    fields.addAll([
      _buildGlassTextField(
        controller: _phoneController,
        focusNode: _phoneFocus,
        nextFocusNode: _getNextFocus('phone'),
        label: 'Phone Number',
        icon: CupertinoIcons.phone,
        keyboardType: TextInputType.phone,
      ),
      const SizedBox(height: 16),
    ]);

    // Email field (all profiles)
    fields.addAll([
      _buildGlassTextField(
        controller: _emailController,
        focusNode: _emailFocus,
        nextFocusNode: _getNextFocus('email'),
        label: 'Email Address',
        icon: CupertinoIcons.mail,
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 16),
    ]);

    // Website field for Professional and Custom
    if (profileType == ProfileType.professional || profileType == ProfileType.custom) {
      fields.addAll([
        _buildGlassTextField(
          controller: _websiteController,
          focusNode: _websiteFocus,
          nextFocusNode: _getNextFocus('website'),
          label: 'Website',
          icon: CupertinoIcons.globe,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 16),
      ]);
    }

    return fields;
  }

  List<Widget> _buildSocialFields() {
    final availableSocials = _getAvailableSocialPlatforms();

    return [
      // Horizontal scrollable chips
      SizedBox(
        height: 56,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: availableSocials.length,
          itemBuilder: (context, index) {
            final social = availableSocials[index];
            final isSelected = _selectedSocialPlatform == social;
            final hasValue = _socialControllers[social]?.text.isNotEmpty ?? false;

            return Padding(
              padding: EdgeInsets.only(right: index < availableSocials.length - 1 ? 8 : 0),
              child: _buildSocialChip(social, isSelected, hasValue),
            );
          },
        ),
      ),
      // Show text field below if a platform is selected
      if (_selectedSocialPlatform != null) ...[
        const SizedBox(height: 16),
        _buildGlassTextField(
          controller: _socialControllers[_selectedSocialPlatform]!,
          focusNode: _socialFocusNodes[_selectedSocialPlatform]!,
          nextFocusNode: null,
          label: _getSocialLabel(_selectedSocialPlatform!),
          icon: _getSocialIcon(_selectedSocialPlatform!),
          prefix: _getSocialPrefix(_selectedSocialPlatform!),
          textInputAction: TextInputAction.done,
          accentColor: _getSocialBrandColor(_selectedSocialPlatform!), // Brand color
          showClearButton: true, // Show clear button
        ),
        const SizedBox(height: 16),
      ],
    ];
  }

  /// Build a social media chip with brand colors
  Widget _buildSocialChip(String social, bool isSelected, bool hasValue) {
    final brandColor = _getSocialBrandColor(social);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            // Toggle selection: if already selected, deselect; otherwise select
            _selectedSocialPlatform = isSelected ? null : social;
            // Focus the text field if selecting
            if (_selectedSocialPlatform != null) {
              Future.delayed(const Duration(milliseconds: 100), () {
                _socialFocusNodes[social]?.requestFocus();
              });
            }
          });
          HapticFeedback.lightImpact();
        },
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              width: 60, // Fixed width for consistent sizing
              height: 54, // Fixed height
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? brandColor.withOpacity(0.15)
                    : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: brandColor.withOpacity(isSelected ? 0.6 : 0.4),
                  width: isSelected ? 2 : 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Centered icon takes up available space
                  Expanded(
                    child: Center(
                      child: Icon(
                        _getSocialIcon(social),
                        color: brandColor,
                        size: 22,
                      ),
                    ),
                  ),
                  // Green pill indicator at bottom - always present
                  Container(
                    width: 18,
                    height: 3,
                    decoration: BoxDecoration(
                      color: hasValue
                          ? AppColors.success
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(1.5),
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

  /// Get brand color for social platform (used in chips only)
  Color _getSocialBrandColor(String social) {
    switch (social.toLowerCase()) {
      case 'linkedin':
        return const Color(0xFF0077B5);
      case 'twitter':
      case 'x':
        return const Color(0xFF000000);
      case 'github':
        return const Color(0xFF333333);
      case 'instagram':
        return const Color(0xFFE4405F);
      case 'snapchat':
        return const Color(0xFFFFFC00);
      case 'facebook':
        return const Color(0xFF1877F2);
      case 'discord':
        return const Color(0xFF5865F2);
      case 'behance':
        return const Color(0xFF1769FF);
      case 'dribbble':
        return const Color(0xFFEA4C89);
      case 'tiktok':
        return const Color(0xFF000000);
      case 'youtube':
        return const Color(0xFFFF0000);
      case 'twitch':
        return const Color(0xFF9146FF);
      default:
        return AppColors.primaryAction;
    }
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

  String _getSocialLabel(String social) {
    switch (social) {
      case 'instagram': return 'Instagram';
      case 'snapchat': return 'Snapchat';
      case 'tiktok': return 'TikTok';
      case 'twitter': return 'Twitter';
      case 'facebook': return 'Facebook';
      case 'linkedin': return 'LinkedIn';
      case 'github': return 'GitHub';
      case 'discord': return 'Discord';
      case 'behance': return 'Behance';
      case 'dribbble': return 'Dribbble';
      case 'youtube': return 'YouTube';
      case 'twitch': return 'Twitch';
      default: return social.toUpperCase();
    }
  }

  IconData _getSocialIcon(String social) {
    switch (social) {
      case 'instagram': return FontAwesomeIcons.instagram;
      case 'snapchat': return FontAwesomeIcons.snapchat;
      case 'tiktok': return FontAwesomeIcons.tiktok;
      case 'twitter': return FontAwesomeIcons.xTwitter;
      case 'facebook': return FontAwesomeIcons.facebook;
      case 'linkedin': return FontAwesomeIcons.linkedin;
      case 'github': return FontAwesomeIcons.github;
      case 'discord': return FontAwesomeIcons.discord;
      case 'behance': return FontAwesomeIcons.behance;
      case 'dribbble': return FontAwesomeIcons.dribbble;
      case 'youtube': return FontAwesomeIcons.youtube;
      case 'twitch': return FontAwesomeIcons.twitch;
      default: return CupertinoIcons.link;
    }
  }

  String? _getSocialPrefix(String social) {
    switch (social) {
      case 'twitter':
      case 'instagram':
      case 'snapchat':
      case 'tiktok':
        return '@';
      case 'linkedin':
        return 'linkedin.com/in/';
      case 'github':
        return 'github.com/';
      case 'behance':
        return 'behance.net/';
      case 'dribbble':
        return 'dribbble.com/';
      default:
        return null;
    }
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocusNode,
    required String label,
    required IconData icon,
    String? prefix,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    String? Function(String?)? validator,
    Color? accentColor, // Brand color for focused state
    bool showClearButton = false, // Show clear button when field has content
  }) {
    final effectiveAccentColor = accentColor ?? AppColors.primaryAction;

    return ValueListenableBuilder<bool>(
      valueListenable: _FocusNotifier(focusNode),
      builder: (context, hasFocus, child) {
        final hasContent = controller.text.isNotEmpty;

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasFocus
                      ? effectiveAccentColor.withOpacity(0.5)
                      : Colors.white.withOpacity(0.25),
                  width: 1.5,
                ),
              ),
              child: TextFormField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: keyboardType,
                textInputAction: textInputAction ?? TextInputAction.next,
                validator: validator,
                style: AppTextStyles.body,
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: AppTextStyles.body.copyWith(
                    color: hasFocus ? effectiveAccentColor : AppColors.textSecondary,
                  ),
                  prefixIcon: Icon(
                    icon,
                    color: hasFocus ? effectiveAccentColor : AppColors.textSecondary,
                    size: 20,
                  ),
                  suffixIcon: showClearButton && hasContent
                      ? IconButton(
                          icon: Icon(
                            CupertinoIcons.xmark_circle_fill,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          onPressed: () {
                            controller.clear();
                            focusNode.unfocus();
                            _onFormChanged(); // Trigger change detection
                          },
                        )
                      : null,
                  prefixText: prefix,
                  prefixStyle: AppTextStyles.body.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  border: InputBorder.none,
                  errorBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorStyle: AppTextStyles.caption.copyWith(
                    color: AppColors.error,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onFieldSubmitted: (value) {
                  if (nextFocusNode != null) {
                    nextFocusNode.requestFocus();
                  } else {
                    focusNode.unfocus();
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTemplateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Card Template',
              style: AppTextStyles.h3.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _recentCombinations.length + _templates.length + 3, // recent + templates + border + background + add bg
            itemBuilder: (context, index) {
              if (index < _recentCombinations.length && _recentCombinations.isNotEmpty) {
                return _buildRecentCombination(index);
              } else if (index < _recentCombinations.length + _templates.length) {
                final templateIndex = index - _recentCombinations.length;
                return _buildTemplatePreview(templateIndex);
              } else if (index == _recentCombinations.length + _templates.length) {
                return _buildBorderColorPicker();
              } else if (index == _recentCombinations.length + _templates.length + 1) {
                return _buildBackgroundPicker();
              } else {
                return _buildAddBackgroundButton();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTemplatePreview(int index) {
    final template = _templates[index];
    final isSelected = index == _selectedTemplate;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedTemplate = index);
        HapticFeedback.lightImpact();
      },
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryAction
                      : Colors.white.withOpacity(0.3),
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [template.primaryColor, template.secondaryColor],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    template.name,
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? AppColors.primaryAction
                          : AppColors.textPrimary,
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

  Widget _buildRecentCombination(int index) {
    final combination = _recentCombinations[index];
    final bgColor = combination['background'];
    final borderColor = combination['border']!;

    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _backgroundColor = bgColor;
              _borderColor = borderColor;
            });
            HapticFeedback.lightImpact();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              gradient: bgColor != null
                ? LinearGradient(
                    colors: [bgColor, bgColor.withOpacity(0.8)],
                  )
                : LinearGradient(
                    colors: [
                      _templates[_selectedTemplate].primaryColor,
                      _templates[_selectedTemplate].secondaryColor,
                    ],
                  ),
              borderRadius: BorderRadius.circular(12),
              border: borderColor != Colors.transparent
                ? Border.all(
                    color: borderColor,
                    width: 2,
                  )
                : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: bgColor ?? _templates[_selectedTemplate].primaryColor,
                    borderRadius: BorderRadius.circular(6),
                    border: borderColor != Colors.transparent
                      ? Border.all(
                          color: borderColor,
                          width: 2,
                        )
                      : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Recent\n#${index + 1}',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w500,
                    color: (bgColor ?? _templates[_selectedTemplate].primaryColor).computeLuminance() > 0.5 ? Colors.black : Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBorderColorPicker() {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showColorPicker,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _borderColor.withOpacity(0.5),
                width: 2,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _borderColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    CupertinoIcons.paintbrush,
                    color: _borderColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Border\nColor',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w500,
                    color: _borderColor,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundPicker() {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showUnifiedBackgroundPicker,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              gradient: _backgroundColor != null
                ? LinearGradient(colors: [_backgroundColor!, _backgroundColor!.withOpacity(0.8)])
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_primaryColor, _secondaryColor],
                  ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 2,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: _backgroundColor != null
                      ? LinearGradient(colors: [_backgroundColor!, _backgroundColor!.withOpacity(0.8)])
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_primaryColor, _secondaryColor],
                        ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    CupertinoIcons.paintbrush_fill,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Background',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddBackgroundButton() {
    final hasBackground = _backgroundImage != null;

    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showImagePicker(isBackground: true),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasBackground
                    ? AppColors.primaryAction.withOpacity(0.5)
                    : Colors.white.withOpacity(0.3),
                width: hasBackground ? 2 : 1,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.primaryAction.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _backgroundImage == null ? CupertinoIcons.photo_on_rectangle : CupertinoIcons.pencil,
                    color: AppColors.primaryAction,
                    size: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Background\nImage',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryAction,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showColorPicker() async {
    Color selectedColor = _borderColor;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Border Color',
                      style: AppTextStyles.h3.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          // Transparent/Remove option first
                          GestureDetector(
                            onTap: () {
                              _updateCardAesthetics(
                                borderColor: Colors.transparent,
                              );
                              Navigator.pop(context);
                              HapticFeedback.lightImpact();
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _borderColor == Colors.transparent
                                    ? AppColors.primaryAction
                                    : Colors.white.withOpacity(0.3),
                                  width: _borderColor == Colors.transparent ? 3 : 1.5,
                                ),
                              ),
                              child: Icon(
                                CupertinoIcons.xmark,
                                color: _borderColor == Colors.transparent
                                  ? AppColors.primaryAction
                                  : AppColors.textSecondary,
                                size: 20,
                              ),
                            ),
                          ),
                          // Regular colors
                          ...[
                            Colors.white,
                            Colors.blue,
                            Colors.purple,
                            Colors.pink,
                            Colors.orange,
                            Colors.green,
                            Colors.red,
                            Colors.yellow,
                            Colors.cyan,
                            Colors.indigo,
                            Colors.teal,
                            Colors.lime,
                          ].map((color) {
                            final isSelected = color.value == _borderColor.value;
                            return GestureDetector(
                              onTap: () {
                                _updateCardAesthetics(
                                  borderColor: color,
                                );
                                Navigator.pop(context);
                                HapticFeedback.lightImpact();
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                      ? AppColors.primaryAction
                                      : Colors.white.withOpacity(0.3),
                                    width: isSelected ? 3 : 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: isSelected
                                  ? Icon(
                                      CupertinoIcons.checkmark,
                                      color: color.computeLuminance() > 0.5
                                        ? Colors.black
                                        : Colors.white,
                                      size: 20,
                                    )
                                  : null,
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 48,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.pop(context),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Cancel',
                                      style: AppTextStyles.body.copyWith(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 48,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _showCustomColorPicker(selectedColor),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryAction.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Custom',
                                      style: AppTextStyles.body.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  void _showCustomColorPicker(Color initialColor) {
    Color selectedColor = initialColor;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Custom Color',
                      style: AppTextStyles.h3.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: ColorPicker(
                        pickerColor: selectedColor,
                        onColorChanged: (color) {
                          selectedColor = color;
                        },
                        colorPickerWidth: 250,
                        pickerAreaHeightPercent: 0.7,
                        enableAlpha: false,
                        displayThumbColor: true,
                        paletteType: PaletteType.hsvWithHue,
                        labelTypes: const [],
                        pickerAreaBorderRadius: BorderRadius.circular(12),
                        hexInputBar: false,
                        portraitOnly: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 48,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.pop(context),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Cancel',
                                      style: AppTextStyles.body.copyWith(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 48,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  _updateCardAesthetics(
                                    borderColor: selectedColor,
                                  );
                                  Navigator.pop(context);
                                  Navigator.pop(context);
                                  HapticFeedback.lightImpact();
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryAction.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Apply',
                                      style: AppTextStyles.body.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  void _showBackgroundColorPicker() async {
    Color selectedColor = _backgroundColor ?? _primaryColor;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Background Color',
                      style: AppTextStyles.h3.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          // Transparent/Remove option first
                          GestureDetector(
                            onTap: () {
                              _updateCardAesthetics(
                                clearBackgroundColor: true,
                              );
                              Navigator.pop(context);
                              HapticFeedback.lightImpact();
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _backgroundColor == null
                                    ? AppColors.primaryAction
                                    : Colors.white.withOpacity(0.3),
                                  width: _backgroundColor == null ? 3 : 1.5,
                                ),
                              ),
                              child: Icon(
                                CupertinoIcons.xmark,
                                color: _backgroundColor == null
                                  ? AppColors.primaryAction
                                  : AppColors.textSecondary,
                                size: 20,
                              ),
                            ),
                          ),
                          // Standard color options
                          ...[
                            Colors.white,
                            Colors.blue,
                            Colors.purple,
                            Colors.pink,
                            Colors.orange,
                            Colors.green,
                            Colors.red,
                            Colors.yellow,
                            Colors.cyan,
                            Colors.indigo,
                            Colors.teal,
                            Colors.lime,
                          ].map((color) {
                            final isSelected = _backgroundColor != null && color.value == _backgroundColor!.value;
                            return GestureDetector(
                              onTap: () {
                                _updateCardAesthetics(
                                  backgroundColor: color,
                                );
                                Navigator.pop(context);
                                HapticFeedback.lightImpact();
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                      ? AppColors.primaryAction
                                      : Colors.white.withOpacity(0.3),
                                    width: isSelected ? 3 : 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: isSelected
                                  ? Icon(
                                      CupertinoIcons.checkmark,
                                      color: color.computeLuminance() > 0.5
                                        ? Colors.black
                                        : Colors.white,
                                      size: 20,
                                    )
                                  : null,
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 48,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.pop(context),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Cancel',
                                      style: AppTextStyles.body.copyWith(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 48,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _showCustomBackgroundColorPicker(selectedColor),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryAction.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Custom',
                                      style: AppTextStyles.body.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  void _showCustomBackgroundColorPicker(Color initialColor) {
    Color selectedColor = initialColor;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Custom Background',
                      style: AppTextStyles.h3.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: ColorPicker(
                        pickerColor: selectedColor,
                        onColorChanged: (color) {
                          selectedColor = color;
                        },
                        colorPickerWidth: 250,
                        pickerAreaHeightPercent: 0.7,
                        enableAlpha: false,
                        displayThumbColor: true,
                        paletteType: PaletteType.hsvWithHue,
                        labelTypes: const [],
                        pickerAreaBorderRadius: BorderRadius.circular(12),
                        hexInputBar: false,
                        portraitOnly: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 48,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.pop(context),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Cancel',
                                      style: AppTextStyles.body.copyWith(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 48,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  _updateCardAesthetics(
                                    backgroundColor: selectedColor,
                                  );
                                  Navigator.pop(context);
                                  Navigator.pop(context);
                                  HapticFeedback.lightImpact();
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryAction.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Apply',
                                      style: AppTextStyles.body.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  void _showGradientBackgroundPicker() {
    Color startColor = _primaryColor;
    Color endColor = _secondaryColor;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  constraints: const BoxConstraints(maxWidth: 400),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.2),
                        Colors.white.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Gradient Background',
                        style: AppTextStyles.h3.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Live gradient preview
                      Container(
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [startColor, endColor],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Start color section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start Color',
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () {
                              _showColorPickerForGradient(
                                initialColor: startColor,
                                title: 'Start Color',
                                onColorSelected: (color) {
                                  setDialogState(() {
                                    startColor = color;
                                  });
                                },
                              );
                            },
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: startColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Tap to change',
                                  style: AppTextStyles.body.copyWith(
                                    color: startColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // End color section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'End Color',
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () {
                              _showColorPickerForGradient(
                                initialColor: endColor,
                                title: 'End Color',
                                onColorSelected: (color) {
                                  setDialogState(() {
                                    endColor = color;
                                  });
                                },
                              );
                            },
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: endColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Tap to change',
                                  style: AppTextStyles.body.copyWith(
                                    color: endColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => Navigator.pop(context),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Cancel',
                                        style: AppTextStyles.body.copyWith(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    // Clear solid backgroundColor and set gradient
                                    _updateCardAesthetics(
                                      clearBackgroundColor: true,
                                      primaryColor: startColor,
                                      secondaryColor: endColor,
                                    );
                                    Navigator.pop(context);
                                    HapticFeedback.lightImpact();
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: AppColors.primaryGradient,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Apply',
                                        style: AppTextStyles.body.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showColorPickerForGradient({
    required Color initialColor,
    required String title,
    required Function(Color) onColorSelected,
  }) {
    Color selectedColor = initialColor;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.h3.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: ColorPicker(
                        pickerColor: selectedColor,
                        onColorChanged: (color) {
                          selectedColor = color;
                        },
                        colorPickerWidth: 250,
                        pickerAreaHeightPercent: 0.7,
                        enableAlpha: false,
                        displayThumbColor: true,
                        paletteType: PaletteType.hsvWithHue,
                        labelTypes: const [],
                        pickerAreaBorderRadius: BorderRadius.circular(12),
                        hexInputBar: false,
                        portraitOnly: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.pop(context),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Cancel',
                                      style: AppTextStyles.body.copyWith(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  onColorSelected(selectedColor);
                                  Navigator.pop(context);
                                  HapticFeedback.lightImpact();
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Select',
                                      style: AppTextStyles.body.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  /// Unified background color picker with solid/gradient toggle
  void _showUnifiedBackgroundPicker() {
    BackgroundMode mode = _backgroundColor != null
      ? BackgroundMode.solid
      : BackgroundMode.gradient;

    Color solidColor = _backgroundColor ?? _primaryColor;
    Color gradientStart = _primaryColor;
    Color gradientEnd = _secondaryColor;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  constraints: const BoxConstraints(maxWidth: 400),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.2),
                        Colors.white.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        'Background',
                        style: AppTextStyles.h3.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Toggle Switch
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      mode = BackgroundMode.solid;
                                    });
                                    HapticFeedback.lightImpact();
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      gradient: mode == BackgroundMode.solid
                                        ? AppColors.primaryGradient
                                        : null,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Solid',
                                        style: AppTextStyles.body.copyWith(
                                          fontWeight: mode == BackgroundMode.solid
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                          color: mode == BackgroundMode.solid
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      mode = BackgroundMode.gradient;
                                    });
                                    HapticFeedback.lightImpact();
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      gradient: mode == BackgroundMode.gradient
                                        ? AppColors.primaryGradient
                                        : null,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Gradient',
                                        style: AppTextStyles.body.copyWith(
                                          fontWeight: mode == BackgroundMode.gradient
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                          color: mode == BackgroundMode.gradient
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Dynamic Content
                      if (mode == BackgroundMode.solid)
                        _buildSolidColorContent(
                          solidColor,
                          (color) {
                            setDialogState(() {
                              solidColor = color;
                            });
                          },
                        )
                      else
                        _buildGradientColorContent(
                          gradientStart,
                          gradientEnd,
                          (start, end) {
                            setDialogState(() {
                              gradientStart = start;
                              gradientEnd = end;
                            });
                          },
                        ),

                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => Navigator.pop(context),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Cancel',
                                        style: AppTextStyles.body.copyWith(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    if (mode == BackgroundMode.solid) {
                                      _updateCardAesthetics(backgroundColor: solidColor);
                                    } else {
                                      _updateCardAesthetics(
                                        clearBackgroundColor: true,
                                        primaryColor: gradientStart,
                                        secondaryColor: gradientEnd,
                                      );
                                    }
                                    Navigator.pop(context);
                                    HapticFeedback.lightImpact();
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: AppColors.primaryGradient,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Apply',
                                        style: AppTextStyles.body.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build solid color picker content
  Widget _buildSolidColorContent(Color selected, Function(Color) onColorSelected) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          // Transparent/Remove option first
          GestureDetector(
            onTap: () {
              _updateCardAesthetics(clearBackgroundColor: true);
              Navigator.pop(context);
              HapticFeedback.lightImpact();
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _backgroundColor == null
                    ? AppColors.primaryAction
                    : Colors.white.withOpacity(0.3),
                  width: _backgroundColor == null ? 3 : 1.5,
                ),
              ),
              child: Icon(
                CupertinoIcons.xmark,
                color: _backgroundColor == null
                  ? AppColors.primaryAction
                  : AppColors.textSecondary,
                size: 20,
              ),
            ),
          ),
          // Standard color options
          ...[
            Colors.white,
            Colors.blue,
            Colors.purple,
            Colors.pink,
            Colors.orange,
            Colors.green,
            Colors.red,
            Colors.yellow,
            Colors.cyan,
            Colors.indigo,
            Colors.teal,
            Colors.lime,
          ].map((color) {
            final isSelected = selected.value == color.value;
            return GestureDetector(
              onTap: () {
                onColorSelected(color);
                HapticFeedback.lightImpact();
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                      ? AppColors.primaryAction
                      : Colors.white.withOpacity(0.3),
                    width: isSelected ? 3 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: isSelected
                  ? Icon(
                      CupertinoIcons.checkmark,
                      color: color.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                      size: 20,
                    )
                  : null,
              ),
            );
          }).toList(),
          // Custom color button
          GestureDetector(
            onTap: () {
              _showCustomBackgroundColorPicker(selected);
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                CupertinoIcons.add,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build gradient color picker content
  Widget _buildGradientColorContent(
    Color start,
    Color end,
    Function(Color, Color) onColorsChanged,
  ) {
    return Column(
      children: [
        // Live gradient preview
        Container(
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [start, end],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 2,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Start color section
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Start Color',
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                _showColorPickerForGradient(
                  initialColor: start,
                  title: 'Start Color',
                  onColorSelected: (color) {
                    onColorsChanged(color, end);
                  },
                );
              },
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: start,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    'Tap to change',
                    style: AppTextStyles.body.copyWith(
                      color: start.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // End color section
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'End Color',
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                _showColorPickerForGradient(
                  initialColor: end,
                  title: 'End Color',
                  onColorSelected: (color) {
                    onColorsChanged(start, color);
                  },
                );
              },
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: end,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    'Tap to change',
                    style: AppTextStyles.body.copyWith(
                      color: end.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _saveColorCombination() {
    // Save combination if either background or border is customized
    if (_backgroundColor != null || _borderColor != Colors.white) {
      final combination = {
        'background': _backgroundColor,
        'border': _borderColor,
      };

      // Remove if already exists
      _recentCombinations.removeWhere((c) =>
        c['background']?.value == combination['background']?.value &&
        c['border']!.value == combination['border']!.value
      );

      // Add to beginning
      _recentCombinations.insert(0, combination);

      // Keep only first 3
      if (_recentCombinations.length > 3) {
        _recentCombinations = _recentCombinations.take(3).toList();
      }
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
      icon: Icon(
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

      // Reset template
      _selectedTemplate = 0;
    });

    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('All content cleared'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

// Template models
class ContactTemplate {
  final String name;
  final Color primaryColor;
  final Color secondaryColor;
  final TemplateBackground backgroundStyle;

  ContactTemplate({
    required this.name,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundStyle,
  });
}

enum TemplateBackground {
  gradient,
  pattern,
  solid,
}

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