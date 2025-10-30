import 'package:flutter/cupertino.dart';

import '../../core/models/profile_models.dart';
import 'form_field_builders.dart';

/// Widget that builds the basic profile information fields
/// based on the selected profile type.
///
/// This widget is extracted from ProfileScreen to improve modularity
/// and reduce the main screen file size.
class ProfileBasicFields extends StatelessWidget {
  final ProfileType profileType;

  // Controllers
  final TextEditingController nameController;
  final TextEditingController titleController;
  final TextEditingController companyController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController websiteController;

  // Focus nodes
  final FocusNode nameFocus;
  final FocusNode titleFocus;
  final FocusNode companyFocus;
  final FocusNode phoneFocus;
  final FocusNode emailFocus;
  final FocusNode websiteFocus;

  // Callbacks
  final VoidCallback? onFormChanged;
  final FocusNode? Function(String fieldName) getNextFocus;

  const ProfileBasicFields({
    super.key,
    required this.profileType,
    required this.nameController,
    required this.titleController,
    required this.companyController,
    required this.phoneController,
    required this.emailController,
    required this.websiteController,
    required this.nameFocus,
    required this.titleFocus,
    required this.companyFocus,
    required this.phoneFocus,
    required this.emailFocus,
    required this.websiteFocus,
    required this.getNextFocus,
    this.onFormChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _buildFields(),
    );
  }

  List<Widget> _buildFields() {
    final fields = <Widget>[];

    // Name field (always required)
    fields.addAll([
      GlassTextField(
        controller: nameController,
        focusNode: nameFocus,
        nextFocusNode: getNextFocus('name'),
        label: 'Full Name',
        icon: CupertinoIcons.person,
        onChanged: onFormChanged,
        validator: FormValidators.validateName,
      ),
      const SizedBox(height: 16),
    ]);

    // Title field for Professional and Custom
    if (profileType == ProfileType.professional || profileType == ProfileType.custom) {
      fields.addAll([
        GlassTextField(
          controller: titleController,
          focusNode: titleFocus,
          nextFocusNode: getNextFocus('title'),
          label: 'Title/Position',
          icon: CupertinoIcons.bag,
          onChanged: onFormChanged,
        ),
        const SizedBox(height: 16),
      ]);
    }

    // Company field for Professional
    if (profileType == ProfileType.professional) {
      fields.addAll([
        GlassTextField(
          controller: companyController,
          focusNode: companyFocus,
          nextFocusNode: getNextFocus('company'),
          label: 'Company',
          icon: CupertinoIcons.building_2_fill,
          onChanged: onFormChanged,
        ),
        const SizedBox(height: 16),
      ]);
    }

    // Phone field (all profiles)
    fields.addAll([
      GlassTextField(
        controller: phoneController,
        focusNode: phoneFocus,
        nextFocusNode: getNextFocus('phone'),
        label: 'Phone Number',
        icon: CupertinoIcons.phone,
        keyboardType: TextInputType.phone,
        onChanged: onFormChanged,
        validator: FormValidators.validatePhone,
      ),
      const SizedBox(height: 16),
    ]);

    // Email field (all profiles)
    fields.addAll([
      GlassTextField(
        controller: emailController,
        focusNode: emailFocus,
        nextFocusNode: getNextFocus('email'),
        label: 'Email Address',
        icon: CupertinoIcons.mail,
        keyboardType: TextInputType.emailAddress,
        onChanged: onFormChanged,
        validator: FormValidators.validateEmail,
      ),
      const SizedBox(height: 16),
    ]);

    // Website field for Professional and Custom
    if (profileType == ProfileType.professional || profileType == ProfileType.custom) {
      fields.addAll([
        GlassTextField(
          controller: websiteController,
          focusNode: websiteFocus,
          nextFocusNode: getNextFocus('website'),
          label: 'Website',
          icon: CupertinoIcons.globe,
          keyboardType: TextInputType.url,
          onChanged: onFormChanged,
          validator: FormValidators.validateUrl,
        ),
        const SizedBox(height: 16),
      ]);
    }

    return fields;
  }
}
