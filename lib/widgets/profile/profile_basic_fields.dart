import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'dart:ui';

import '../../core/models/profile_models.dart';
import '../../theme/theme.dart';
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

    // Phone field (all profiles) - with international formatting
    fields.addAll([
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: IntlPhoneField(
              controller: phoneController,
              focusNode: phoneFocus,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                labelStyle: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
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
              style: AppTextStyles.body,
              dropdownTextStyle: AppTextStyles.body,
              initialCountryCode: 'US',
              showCountryFlag: true,
              showDropdownIcon: true,
              dropdownIcon: Icon(
                CupertinoIcons.chevron_down,
                color: AppColors.textSecondary,
                size: 20,
              ),
              flagsButtonPadding: const EdgeInsets.only(left: 12),
              onChanged: (phone) {
                // Update controller with full international number
                phoneController.text = phone.completeNumber;
                onFormChanged?.call();
              },
              onSubmitted: (value) {
                final nextFocus = getNextFocus('phone');
                if (nextFocus != null) {
                  nextFocus.requestFocus();
                } else {
                  phoneFocus.unfocus();
                }
              },
              validator: (phone) {
                if (phone == null || phone.number.isEmpty) {
                  return null; // Optional field
                }
                // IntlPhoneField handles validation internally
                return null;
              },
            ),
          ),
        ),
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
