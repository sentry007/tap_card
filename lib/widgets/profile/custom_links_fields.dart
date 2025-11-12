import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

import '../../core/models/profile_models.dart';
import '../../theme/theme.dart';
import '../common/section_header_with_info.dart';
import 'form_field_builders.dart';

/// Widget that builds the custom link fields (up to 3 links).
///
/// This widget manages custom link creation, editing, and deletion.
/// Each link has a title and URL, and users can add up to 3 custom links.
///
/// Features:
/// - Horizontal scrollable chips for existing links
/// - Add button when fewer than 3 links exist
/// - Title and URL input fields for selected link
/// - Delete button for removing links
/// - Visual indicator (green pill) for completed links
/// - Auto-focus on link selection
class CustomLinksFields extends StatefulWidget {
  final ProfileData? currentProfile;
  final List<TextEditingController> customLinkTitleControllers;
  final List<TextEditingController> customLinkUrlControllers;
  final List<FocusNode> customLinkTitleFocusNodes;
  final List<FocusNode> customLinkUrlFocusNodes;
  final VoidCallback? onFormChanged;

  const CustomLinksFields({
    super.key,
    required this.currentProfile,
    required this.customLinkTitleControllers,
    required this.customLinkUrlControllers,
    required this.customLinkTitleFocusNodes,
    required this.customLinkUrlFocusNodes,
    this.onFormChanged,
  });

  @override
  State<CustomLinksFields> createState() => _CustomLinksFieldsState();
}

class _CustomLinksFieldsState extends State<CustomLinksFields> {
  int? _selectedCustomLinkIndex;

  @override
  void initState() {
    super.initState();
    // Ensure we have controllers for existing custom links from profile
    _ensureCustomLinkControllers();
  }

  @override
  void didUpdateWidget(CustomLinksFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controllers if profile changed
    if (oldWidget.currentProfile != widget.currentProfile) {
      _ensureCustomLinkControllers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeaderWithInfo(
          title: 'Custom Links',
          infoText: 'Add up to 3 custom links to your profile (portfolio, blog, store, etc.). Each link needs a title and URL. Tap the + button to add a new link.',
        ),
        const SizedBox(height: 16),
        // Show horizontal scrollable chips for existing/available links
        SizedBox(
          height: 56,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: widget.customLinkTitleControllers.length +
                       (widget.customLinkTitleControllers.length < 3 ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < widget.customLinkTitleControllers.length) {
                // Existing link chip
                final isSelected = _selectedCustomLinkIndex == index;
                final hasValue = widget.customLinkTitleControllers[index].text.isNotEmpty &&
                                 widget.customLinkUrlControllers[index].text.isNotEmpty;
                return Padding(
                  padding: EdgeInsets.only(right: index < widget.customLinkTitleControllers.length ? 8 : 0),
                  child: _buildCustomLinkChip(index, isSelected, hasValue),
                );
              } else {
                // Add new link button (only if < 3 links)
                return _buildAddCustomLinkChip();
              }
            },
          ),
        ),
        // Show text fields if a link is selected
        if (_selectedCustomLinkIndex != null &&
            _selectedCustomLinkIndex! < widget.customLinkTitleControllers.length) ...[
          const SizedBox(height: 16),
          GlassTextField(
            controller: widget.customLinkTitleControllers[_selectedCustomLinkIndex!],
            focusNode: widget.customLinkTitleFocusNodes[_selectedCustomLinkIndex!],
            nextFocusNode: widget.customLinkUrlFocusNodes[_selectedCustomLinkIndex!],
            label: 'Link Title',
            icon: CupertinoIcons.textformat,
            textInputAction: TextInputAction.next,
            showClearButton: false,
            onChanged: widget.onFormChanged,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GlassTextField(
                  controller: widget.customLinkUrlControllers[_selectedCustomLinkIndex!],
                  focusNode: widget.customLinkUrlFocusNodes[_selectedCustomLinkIndex!],
                  nextFocusNode: null,
                  label: 'URL',
                  icon: CupertinoIcons.link,
                  prefix: 'https://',
                  textInputAction: TextInputAction.done,
                  showClearButton: false,
                  onChanged: widget.onFormChanged,
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    // Delete this custom link
                    setState(() {
                      _removeCustomLinkAt(_selectedCustomLinkIndex!);
                      _selectedCustomLinkIndex = null;
                    });
                    HapticFeedback.lightImpact();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 48,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.error.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.delete,
                      color: AppColors.error,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  /// Ensure we have controllers for all custom links in the current profile
  void _ensureCustomLinkControllers() {
    if (widget.currentProfile == null) return;

    final profileLinks = widget.currentProfile!.customLinks;

    // If we have fewer controllers than profile links, add missing ones
    while (widget.customLinkTitleControllers.length < profileLinks.length) {
      final index = widget.customLinkTitleControllers.length;
      final titleController = TextEditingController(text: profileLinks[index].title);
      final urlController = TextEditingController(text: profileLinks[index].url);

      titleController.addListener(() => widget.onFormChanged?.call());
      urlController.addListener(() => widget.onFormChanged?.call());

      widget.customLinkTitleControllers.add(titleController);
      widget.customLinkUrlControllers.add(urlController);
      widget.customLinkTitleFocusNodes.add(FocusNode());
      widget.customLinkUrlFocusNodes.add(FocusNode());
    }
  }

  /// Build a custom link chip
  Widget _buildCustomLinkChip(int index, bool isSelected, bool hasValue) {
    const linkColor = AppColors.primaryAction;
    final title = widget.customLinkTitleControllers[index].text.isEmpty
        ? 'Link ${index + 1}'
        : widget.customLinkTitleControllers[index].text;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCustomLinkIndex = isSelected ? null : index;
            if (_selectedCustomLinkIndex != null) {
              Future.delayed(const Duration(milliseconds: 100), () {
                widget.customLinkTitleFocusNodes[index].requestFocus();
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              constraints: const BoxConstraints(minWidth: 80, maxWidth: 120),
              height: 54,
              decoration: BoxDecoration(
                color: isSelected
                    ? linkColor.withOpacity(0.15)
                    : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: linkColor.withOpacity(isSelected ? 0.6 : 0.4),
                  width: isSelected ? 2 : 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            CupertinoIcons.link,
                            color: linkColor,
                            size: 18,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            title,
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 18,
                    height: 3,
                    decoration: BoxDecoration(
                      color: hasValue ? AppColors.success : Colors.transparent,
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

  /// Build "Add Link" chip
  Widget _buildAddCustomLinkChip() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            // Add new link controllers
            final titleController = TextEditingController();
            final urlController = TextEditingController();

            titleController.addListener(() => widget.onFormChanged?.call());
            urlController.addListener(() => widget.onFormChanged?.call());

            widget.customLinkTitleControllers.add(titleController);
            widget.customLinkUrlControllers.add(urlController);
            widget.customLinkTitleFocusNodes.add(FocusNode());
            widget.customLinkUrlFocusNodes.add(FocusNode());

            // Select the newly added link
            _selectedCustomLinkIndex = widget.customLinkTitleControllers.length - 1;

            // Focus the title field
            Future.delayed(const Duration(milliseconds: 100), () {
              widget.customLinkTitleFocusNodes[_selectedCustomLinkIndex!].requestFocus();
            });
          });
          HapticFeedback.lightImpact();
        },
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              width: 60,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryAction.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                CupertinoIcons.add,
                color: AppColors.primaryAction,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Remove custom link at index
  void _removeCustomLinkAt(int index) {
    if (index >= 0 && index < widget.customLinkTitleControllers.length) {
      widget.customLinkTitleControllers[index].dispose();
      widget.customLinkUrlControllers[index].dispose();
      widget.customLinkTitleFocusNodes[index].dispose();
      widget.customLinkUrlFocusNodes[index].dispose();

      widget.customLinkTitleControllers.removeAt(index);
      widget.customLinkUrlControllers.removeAt(index);
      widget.customLinkTitleFocusNodes.removeAt(index);
      widget.customLinkUrlFocusNodes.removeAt(index);
    }
  }
}
