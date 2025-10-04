/// Widget Keys for Testing and Debugging
///
/// Centralizes all widget keys used throughout the application for easier
/// testing, debugging, and maintenance. Keys are organized by screen/component.
///
/// Usage:
/// ```dart
/// Container(key: WidgetKeys.homeScreen, ...)
/// ```
library;

import 'package:flutter/widgets.dart';

/// Main Application Keys
class WidgetKeys {
  WidgetKeys._(); // Private constructor

  // ========== App-Level Keys ==========
  static const Key appMultiProvider = Key('app_multi_provider');
  static const Key appStateConsumer = Key('app_state_consumer');
  static const Key appMaterialRouter = Key('app_material_router');
  static const Key appSystemUiRegion = Key('app_system_ui_region');
  static const Key appFallbackBox = Key('app_fallback_box');

  // ========== Home Screen Keys ==========
  static const Key homeScreen = Key('home-screen');
  static const Key homeBackground = Key('home-background');
  static const Key homeLayout = Key('home-layout');
  static const Key homeContent = Key('home-content');
  static const Key homeScroll = Key('home-scroll');

  // Home App Bar
  static const Key homeAppbarSafeArea = Key('appbar-safe-area');
  static const Key homeAppbarContainer = Key('appbar-container');
  static const Key homeAppbarGlass = Key('appbar-glass');
  static const Key homeAppbarContent = Key('appbar-content');
  static const Key homeAppbarLogo = Key('appbar-logo');

  // Home Mode Toggle
  static const Key homeModeToggleMaterial = Key('home_mode_toggle_material');
  static const Key homeModeToggleInkwell = Key('home_mode_toggle_inkwell');
  static const Key homeModeToggleContainer = Key('home_mode_toggle_container');
  static const Key homeModeToggleIcon = Key('home_mode_toggle_icon');

  // Home NFC FAB
  static const Key homeNfcFab = Key('nfc-fab');
  static const Key homeNfcFabContainer = Key('nfc-fab-container');
  static const Key homeNfcFabGlow = Key('nfc-fab-glow');
  static const Key homeNfcFabMain = Key('home_nfc_fab_main');
  static const Key homeNfcFabMaterial = Key('home_nfc_fab_material');
  static const Key homeNfcFabInkwell = Key('home_nfc_fab_inkwell');
  static const Key homeNfcFabCenter = Key('home_nfc_fab_center');
  static const Key homeNfcFabLoading = Key('home_nfc_fab_loading');
  static const Key homeNfcFabProgress = Key('home_nfc_fab_progress');
  static const Key homeNfcFabIconContainer = Key('home_nfc_fab_icon_container');

  // Home Tap to Share Section
  static const Key homeTapShareColumn = Key('home_tap_share_column');
  static const Key homeTapShareTitle = Key('home_tap_share_title');
  static const Key homeTapShareSpacing = Key('home_tap_share_spacing');
  static const Key homeShareOptionsMaterial = Key('home_share_options_material');
  static const Key homeShareOptionsInkwell = Key('home_share_options_inkwell');
  static const Key homeShareOptionsClip = Key('home_share_options_clip');
  static const Key homeShareOptionsBackdrop = Key('home_share_options_backdrop');
  static const Key homeShareOptionsContainer = Key('home_share_options_container');
  static const Key homeShareOptionsRow = Key('home_share_options_row');
  static const Key homeShareOptionsIcon = Key('home_share_options_icon');
  static const Key homeShareOptionsTextSpacing = Key('home_share_options_text_spacing');
  static const Key homeShareOptionsText = Key('home_share_options_text');

  // Home Card Preview
  static const Key homeCardPreviewLoading = Key('home_card_preview_loading');
  static const Key homeCardPreviewContainer = Key('home_card_preview_container');
  static const Key homeCardPreviewName = Key('home_card_preview_name');
  static const Key homeCardPreviewTitle = Key('home_card_preview_title');
  static const Key homeCardPreviewEmailIcon = Key('home_card_preview_email_icon');
  static const Key homeCardPreviewEmail = Key('home_card_preview_email');
  static const Key homeCardPreviewPhoneIcon = Key('home_card_preview_phone_icon');
  static const Key homeCardPreviewPhone = Key('home_card_preview_phone');
  static const Key homeCardPreviewCompanyIcon = Key('home_card_preview_company_icon');
  static const Key homeCardPreviewCompany = Key('home_card_preview_company');

  // Home Preview Text
  static const Key homePreviewTextColumn = Key('home_preview_text_column');
  static const Key homePreviewTitle = Key('home_preview_title');
  static const Key homePreviewSubtitleSpacing = Key('home_preview_subtitle_spacing');
  static const Key homePreviewSubtitle = Key('home_preview_subtitle');

  // Home Contacts Section
  static const Key homeContactsSection = Key('contacts-section');
  static const Key homeContactsList = Key('contacts-list');
  static const Key homeContactsLoadingList = Key('home_contacts_loading_list');
  static const Key homeContactsEmptyCenter = Key('home_contacts_empty_center');
  static const Key homeContactsEmptyColumn = Key('home_contacts_empty_column');
  static const Key homeContactsEmptyIcon = Key('home_contacts_empty_icon');
  static const Key homeContactsEmptySpacing = Key('home_contacts_empty_spacing');
  static const Key homeContactsEmptyText = Key('home_contacts_empty_text');
  static const Key homeContactsListAnimated = Key('home_contacts_list_animated');
  static const Key homeContactsListTransform = Key('home_contacts_list_transform');
  static const Key homeContactsListOpacity = Key('home_contacts_list_opacity');
  static const Key homeContactsListView = Key('home_contacts_list_view');
  static const Key homeContactAvatarSpacing = Key('home_contact_avatar_spacing');

  // Home History Section
  static const Key homeHistoryStrip = Key('home_history_strip');
  static const Key homeHistoryTitlePadding = Key('home_history_title_padding');
  static const Key homeHistoryTitle = Key('home_history_title');
  static const Key homeHistoryTitleSpacing = Key('home_history_title_spacing');
  static const Key homeHistoryListContainer = Key('home_history_list_container');
  static const Key homeHistoryEmptyCenter = Key('home_history_empty_center');
  static const Key homeHistoryEmptyColumn = Key('home_history_empty_column');
  static const Key homeHistoryEmptyIcon = Key('home_history_empty_icon');
  static const Key homeHistoryEmptySpacing = Key('home_history_empty_spacing');
  static const Key homeHistoryEmptyText = Key('home_history_empty_text');
  static const Key homeHistoryListView = Key('home_history_list_view');
  static const Key homeHistoryContentSpacing = Key('home_history_content_spacing');

  // ========== Profile Screen Keys ==========
  static const Key profileScaffold = Key('profile_scaffold');
  static const Key profileMainContainer = Key('profile_main_container');
  static const Key profileMainColumn = Key('profile_main_column');
  static const Key profileExpandedContent = Key('profile_expanded_content');
  static const Key profileScrollView = Key('profile_scroll_view');
  static const Key profileFormColumn = Key('profile_form_column');
  static const Key profileTopSpacing = Key('profile_top_spacing');
  static const Key profilePreviewSpacing = Key('profile_preview_spacing');
  static const Key profileBlurSpacing = Key('profile_blur_spacing');
  static const Key profileTemplateSpacing = Key('profile_template_spacing');
  static const Key profileSelectorSpacing = Key('profile_selector_spacing');
  static const Key profileFormSpacing = Key('profile_form_spacing');
  static const Key profileBottomSpacing = Key('profile_bottom_spacing');

  // Profile App Bar
  static const Key profileAppbarSafeArea = Key('profile_appbar_safe_area');
  static const Key profileAppbarContainer = Key('profile_appbar_container');
  static const Key profileAppbarClip = Key('profile_appbar_clip');
  static const Key profileAppbarBackdrop = Key('profile_appbar_backdrop');
  static const Key profileAppbarContentContainer = Key('profile_appbar_content_container');
  static const Key profileAppbarRow = Key('profile_appbar_row');
  static const Key profileAppbarClearButtonMaterial = Key('profile_appbar_clear_button_material');
  static const Key profileAppbarClearButtonInkwell = Key('profile_appbar_clear_button_inkwell');
  static const Key profileAppbarClearButtonContainer = Key('profile_appbar_clear_button_container');
  static const Key profileAppbarClearIcon = Key('profile_appbar_clear_icon');
  static const Key profileAppbarTitleSection = Key('profile_appbar_title_section');
  static const Key profileAppbarTitleText = Key('profile_appbar_title_text');
  static const Key profileAppbarSettingsButtonMaterial = Key('profile_appbar_settings_button_material');
  static const Key profileAppbarSettingsButtonInkwell = Key('profile_appbar_settings_button_inkwell');
  static const Key profileAppbarSettingsButtonContainer = Key('profile_appbar_settings_button_container');
  static const Key profileAppbarSettingsIcon = Key('profile_appbar_settings_icon');

  // ========== Helper Methods for Dynamic Keys ==========

  /// Generate key for home app bar icon
  static Key homeAppbarIcon(String name) => Key('home_appbar_${name}_material');
  static Key homeAppbarIconInkwell(String name) => Key('home_appbar_${name}_inkwell');
  static Key homeAppbarIconContainer(String name) => Key('home_appbar_${name}_container');
  static Key homeAppbarIconElement(String name) => Key('home_appbar_${name}_icon');

  /// Generate key for NFC FAB ripple
  static Key homeNfcFabRipple(int index) => Key('home_nfc_fab_ripple_$index');

  /// Generate key for contact loading item
  static Key homeContactsLoadingItem(int index) => Key('home_contacts_loading_item_$index');
  static Key homeContactsLoadingClip(int index) => Key('home_contacts_loading_clip_$index');
  static Key homeContactsLoadingBackdrop(int index) => Key('home_contacts_loading_backdrop_$index');
  static Key homeContactsLoadingContainer(int index) => Key('home_contacts_loading_container_$index');
  static Key homeContactsLoadingColumn(int index) => Key('home_contacts_loading_column_$index');
  static Key homeContactsLoadingAvatar(int index) => Key('home_contacts_loading_avatar_$index');
  static Key homeContactsLoadingName(int index) => Key('home_contacts_loading_name_$index');

  /// Generate key for contact card
  static Key homeContactCard(int index) => Key('home_contact_card_$index');
  static Key homeContactClip(int index) => Key('home_contact_clip_$index');
  static Key homeContactBackdrop(int index) => Key('home_contact_backdrop_$index');
  static Key homeContactContainer(int index) => Key('home_contact_container_$index');
  static Key homeContactMaterial(int index) => Key('home_contact_material_$index');
  static Key homeContactInkwell(int index) => Key('home_contact_inkwell_$index');
  static Key homeContactPadding(int index) => Key('home_contact_padding_$index');
  static Key homeContactColumn(int index) => Key('home_contact_column_$index');
  static Key homeContactAvatar(int index) => Key('home_contact_avatar_$index');
  static Key homeContactName(int index) => Key('home_contact_name_$index');
  static Key homeContactLastShared(int index) => Key('home_contact_last_shared_$index');

  /// Generate key for history card
  static Key homeHistoryCard(int index) => Key('home_history_card_$index');
  static Key homeHistoryClip(int index) => Key('home_history_clip_$index');
  static Key homeHistoryBackdrop(int index) => Key('home_history_backdrop_$index');
  static Key homeHistoryContainer(int index) => Key('home_history_container_$index');
  static Key homeHistoryMaterial(int index) => Key('home_history_material_$index');
  static Key homeHistoryInkwell(int index) => Key('home_history_inkwell_$index');
  static Key homeHistoryPadding(int index) => Key('home_history_padding_$index');
  static Key homeHistoryRow(int index) => Key('home_history_row_$index');
  static Key homeHistoryIconContainer(int index) => Key('home_history_icon_container_$index');
  static Key homeHistoryIcon(int index) => Key('home_history_icon_$index');
  static Key homeHistoryContent(int index) => Key('home_history_content_$index');
  static Key homeHistoryContentColumn(int index) => Key('home_history_content_column_$index');
  static Key homeHistoryItemTitle(int index) => Key('home_history_item_title_$index');
  static Key homeHistoryName(int index) => Key('home_history_name_$index');
  static Key homeHistoryTime(int index) => Key('home_history_time_$index');
  static Key homeHistoryMethod(int index) => Key('home_history_method_$index');
}
