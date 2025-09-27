import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'dart:io';

import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import '../../core/constants/routes.dart';
import '../../core/models/profile_models.dart';
import '../../core/services/profile_service.dart';

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
  int _selectedTemplate = 0;
  bool _isSaving = false;
  ProfileData? _currentProfile;
  ProfileType _selectedProfileType = ProfileType.personal;
  final ImagePicker _picker = ImagePicker();

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
      _selectedProfileType = activeProfile.type;
      _populateFormFromProfile(activeProfile);
      _setupSocialControllers();
      setState(() {});
    }
  }

  void _populateFormFromProfile(ProfileData profile) {
    _nameController.text = profile.name;
    _titleController.text = profile.title ?? '';
    _companyController.text = profile.company ?? '';
    _phoneController.text = profile.phone ?? '';
    _emailController.text = profile.email ?? '';
    _websiteController.text = profile.website ?? '';
    _selectedTemplate = profile.templateIndex;

    if (profile.profileImagePath != null) {
      _profileImage = File(profile.profileImagePath!);
    } else {
      _profileImage = null;
    }

    // Load background image if exists
    final backgroundPath = profile.socialMedia['backgroundImage'];
    if (backgroundPath != null && backgroundPath.isNotEmpty) {
      _backgroundImage = File(backgroundPath);
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

      // Add listeners
      _socialControllers[social]!.addListener(_updatePreview);
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
    // Add listeners for real-time preview updates
    _nameController.addListener(_updatePreview);
    _titleController.addListener(_updatePreview);
    _companyController.addListener(_updatePreview);
    _phoneController.addListener(_updatePreview);
    _emailController.addListener(_updatePreview);
    _websiteController.addListener(_updatePreview);
  }

  void _updatePreview() {
    setState(() {}); // Trigger rebuild for live preview
  }

  Future<void> _pickImage(ImageSource source, {bool isBackground = false}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: isBackground ? 1024 : 512,
        maxHeight: isBackground ? 1024 : 512,
        imageQuality: isBackground ? 90 : 80,
      );

      if (image != null) {
        setState(() {
          if (isBackground) {
            _backgroundImage = File(image.path);
          } else {
            _profileImage = File(image.path);
          }
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      // Handle error
      print('Error picking image: $e');
    }
  }

  void _showImagePicker({bool isBackground = false}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildImagePickerModal(isBackground: isBackground),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.mediumImpact();
    _saveController.forward().then((_) => _saveController.reverse());

    setState(() => _isSaving = true);

    await _saveCurrentProfile();

    if (mounted) {
      setState(() => _isSaving = false);

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

    // Add background image to social media data if present
    if (_backgroundImage != null) {
      socialMediaData['backgroundImage'] = _backgroundImage!.path;
    }

    // Create updated profile
    final updatedProfile = _currentProfile!.copyWith(
      name: _nameController.text.trim(),
      title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
      company: _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
      socialMedia: socialMediaData,
      profileImagePath: _profileImage?.path,
      templateIndex: _selectedTemplate,
    );

    await _profileService.updateProfile(updatedProfile);
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
    return Scaffold(
      key: const Key('profile_scaffold'),
      body: Container(
        key: const Key('profile_main_container'),
        width: double.infinity,
        height: double.infinity,
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
        child: Column(
          key: const Key('profile_main_column'),
          children: [
            _buildGlassAppBar(),
            Expanded(
              key: const Key('profile_expanded_content'),
              child: SingleChildScrollView(
                key: const Key('profile_scroll_view'),
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    key: const Key('profile_form_column'),
                    children: [
                      const SizedBox(key: Key('profile_top_spacing'), height: 8),
                      _buildProfilePhotoPicker(),
                      const SizedBox(key: Key('profile_photo_spacing'), height: 24),
                      if (_profileService.multipleProfilesEnabled) ...[
                        _buildProfileSelector(),
                        const SizedBox(key: Key('profile_selector_spacing'), height: 24),
                      ],
                      _buildFormSection(),
                      const SizedBox(key: Key('profile_form_spacing'), height: 24),
                      _buildTemplateSelector(),
                      const SizedBox(key: Key('profile_template_spacing'), height: 24),
                      _buildLivePreview(),
                      const SizedBox(key: Key('profile_preview_spacing'), height: 32),
                      _buildSaveButton(),
                      const SizedBox(key: Key('profile_bottom_spacing'), height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassAppBar() {
    return SafeArea(
      key: const Key('profile_appbar_safe_area'),
      bottom: false,
      child: Container(
        key: const Key('profile_appbar_container'),
        height: 64,
        margin: const EdgeInsets.all(16),
        color: Colors.transparent,
        child: ClipRRect(
          key: const Key('profile_appbar_clip'),
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            key: const Key('profile_appbar_backdrop'),
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
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
                          Icons.clear_all,
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
                          Icons.settings_outlined,
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

  Widget _buildProfilePhotoPicker() {
    return AnimatedBuilder(
      animation: _formController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _formSlide.value * 50),
          child: Opacity(
            opacity: 1.0 - _formSlide.value,
            child: Center(
              child: GestureDetector(
                onTap: _showImagePicker,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: AppColors.glassBorder,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(48),
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: _profileImage == null
                                ? AppColors.primaryGradient
                                : null,
                          ),
                          child: _profileImage == null
                              ? const Icon(
                                  Icons.person,
                                  size: 40,
                                  color: AppColors.textPrimary,
                                )
                              : Image.file(
                                  _profileImage!,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        // Camera overlay
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primaryAction,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.primaryBackground,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryAction.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
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

  Widget _buildImagePickerModal({bool isBackground = false}) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
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
                        icon: Icons.camera_alt,
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
                        icon: Icons.photo_library,
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
                  const SizedBox(height: 16),
                  _buildImagePickerOption(
                    icon: Icons.clear,
                    title: 'Remove Background',
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _backgroundImage = null;
                      });
                      HapticFeedback.lightImpact();
                    },
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
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
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
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: ProfileType.values.length,
                    itemBuilder: (context, index) {
                      final profileType = ProfileType.values[index];
                      final profile = _profileService.getProfileByType(profileType);
                      final isSelected = profile?.id == _currentProfile?.id;

                      return _buildProfileTypeCard(profileType, isSelected);
                    },
                  ),
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
        width: 100,
        margin: const EdgeInsets.only(right: 12),
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
        return Icons.person_outline;
      case ProfileType.professional:
        return Icons.business_center_outlined;
      case ProfileType.custom:
        return Icons.tune_outlined;
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
        icon: Icons.person_outline,
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
          icon: Icons.work_outline,
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
          icon: Icons.business_outlined,
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
        icon: Icons.phone_outlined,
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
        icon: Icons.email_outlined,
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
          icon: Icons.language_outlined,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 16),
      ]);
    }

    return fields;
  }

  List<Widget> _buildSocialFields() {
    final fields = <Widget>[];
    final availableSocials = _getAvailableSocialPlatforms();

    for (int i = 0; i < availableSocials.length; i++) {
      final social = availableSocials[i];
      final controller = _socialControllers[social];
      final focusNode = _socialFocusNodes[social];

      if (controller != null && focusNode != null) {
        fields.addAll([
          _buildGlassTextField(
            controller: controller,
            focusNode: focusNode,
            nextFocusNode: i < availableSocials.length - 1
                ? _socialFocusNodes[availableSocials[i + 1]]
                : null,
            label: _getSocialLabel(social),
            icon: _getSocialIcon(social),
            prefix: _getSocialPrefix(social),
            textInputAction: i == availableSocials.length - 1
                ? TextInputAction.done
                : TextInputAction.next,
          ),
          const SizedBox(height: 16),
        ]);
      }
    }

    return fields;
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
      case 'instagram': return Icons.camera_alt_outlined;
      case 'snapchat': return Icons.camera_outlined;
      case 'tiktok': return Icons.music_video_outlined;
      case 'twitter': return Icons.alternate_email;
      case 'facebook': return Icons.facebook_outlined;
      case 'linkedin': return Icons.business_center_outlined;
      case 'github': return Icons.code_outlined;
      case 'discord': return Icons.chat_outlined;
      case 'behance': return Icons.palette_outlined;
      case 'dribbble': return Icons.design_services_outlined;
      case 'youtube': return Icons.video_library_outlined;
      case 'twitch': return Icons.live_tv_outlined;
      default: return Icons.link_outlined;
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
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: focusNode.hasFocus
                  ? AppColors.primaryAction.withOpacity(0.5)
                  : Colors.white.withOpacity(0.2),
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
                color: AppColors.textSecondary,
              ),
              prefixIcon: Icon(
                icon,
                color: AppColors.textSecondary,
                size: 20,
              ),
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
                vertical: 16,
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
            itemCount: _templates.length + 1, // +1 for the add background button
            itemBuilder: (context, index) {
              if (index < _templates.length) {
                return _buildTemplatePreview(index);
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
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
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

  Widget _buildAddBackgroundButton() {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(left: 12),
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
                color: AppColors.primaryAction.withOpacity(0.5),
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
                    color: AppColors.primaryAction.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _backgroundImage == null ? Icons.add_photo_alternate_outlined : Icons.edit,
                    color: AppColors.primaryAction,
                    size: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _backgroundImage == null ? 'Add\nBackground' : 'Edit\nBackground',
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

  Widget _buildContactCard() {
    return Container(
      width: double.infinity,
      height: 200,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Background image if present
            if (_backgroundImage != null)
              Positioned.fill(
                child: Image.file(
                  _backgroundImage!,
                  fit: BoxFit.cover,
                ),
              ),
            // Overlay for backdrop filter and content
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(_backgroundImage != null ? 0.3 : 0.2),
                      Colors.white.withOpacity(_backgroundImage != null ? 0.15 : 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with avatar and name
                      Row(
                        children: [
                          Container(
                            width: 45,
                            height: 45,
                            decoration: BoxDecoration(
                              gradient: _profileImage == null ? AppColors.primaryGradient : null,
                              borderRadius: BorderRadius.circular(22.5),
                            ),
                            child: _profileImage == null
                                ? const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 24,
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(22.5),
                                    child: Image.file(
                                      _profileImage!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _nameController.text.isEmpty
                                      ? 'Your Name'
                                      : _nameController.text,
                                  style: AppTextStyles.body.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _titleController.text.isEmpty
                                      ? (_selectedProfileType == ProfileType.professional || _selectedProfileType == ProfileType.custom
                                          ? 'Your Title'
                                          : '')
                                      : _titleController.text,
                                  style: AppTextStyles.caption.copyWith(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Contact info
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_emailController.text.isNotEmpty) ...[
                              Row(
                                children: [
                                  Icon(
                                    Icons.email,
                                    size: 14,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _emailController.text,
                                      style: AppTextStyles.caption.copyWith(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 11,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                            ],
                            if (_phoneController.text.isNotEmpty) ...[
                              Row(
                                children: [
                                  Icon(
                                    Icons.phone,
                                    size: 14,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _phoneController.text,
                                      style: AppTextStyles.caption.copyWith(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 11,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                            ],
                            if (_companyController.text.isNotEmpty) ...[
                              Row(
                                children: [
                                  Icon(
                                    Icons.business,
                                    size: 14,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _companyController.text,
                                      style: AppTextStyles.caption.copyWith(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 11,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return AnimatedBuilder(
      animation: _saveController,
      builder: (context, child) {
        return Transform.scale(
          scale: _saveScale.value,
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: AppButton.contained(
              text: _isSaving ? 'Saving...' : 'Save Profile',
              loading: _isSaving,
              onPressed: _isSaving ? null : _saveProfile,
              icon: _isSaving
                  ? null
                  : const Icon(Icons.save, size: 20),
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
        Icons.warning_amber_rounded,
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