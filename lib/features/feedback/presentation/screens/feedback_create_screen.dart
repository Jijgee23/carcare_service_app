import 'dart:io';

import 'package:flutter/material.dart' hide Feedback;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/core/widgets/common/common_widgets.dart';
import 'package:carcare_service/core/widgets/dialogs/message.dart';
import 'package:carcare_service/features/feedback/data/feedback_repository.dart';
import 'package:carcare_service/features/feedback/domain/feedback.dart';
import 'package:carcare_service/features/feedback/domain/feedback_repository.dart';
import 'package:carcare_service/features/feedback/presentation/controllers/feedback_create_controller.dart';
import 'package:carcare_service/features/feedback/presentation/widgets/feedback_vocab.dart';
import 'package:carcare_service/core/utils/upload_image.dart';

/// Create a new Feedback ticket — P7-F3 (D-176). Type/message/optional
/// screenshot, exactly `FeedbackRepository.createFeedback`'s contract.
///
/// Screenshot uses this app's existing `image_picker` approach — the same
/// package/API `NewInspectionScreen`'s `_PhotoInput` already uses
/// (`ImagePicker().pickImage`), just a single image here instead of
/// `pickMultiImage`, since the server accepts one `screenshot` file.
///
/// **Not wired to a route** — intended path: `/feedback/new`. [onCreated] is
/// a hook, invoked with the created ticket so the caller can navigate to its
/// detail screen; when null this screen simply pops on success.
class FeedbackCreateScreen extends StatelessWidget {
  const FeedbackCreateScreen({super.key, this.repository, this.onCreated});

  final FeedbackRepository? repository;
  final ValueChanged<Feedback>? onCreated;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => FeedbackCreateController(repo: repository),
    child: _Body(onCreated: onCreated),
  );
}

class _Body extends StatefulWidget {
  const _Body({this.onCreated});
  final ValueChanged<Feedback>? onCreated;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  final _messageController = TextEditingController();
  FeedbackType _type = FeedbackType.bug;
  String? _screenshotPath;
  String? _messageError;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: uploadImageQuality,
      maxWidth: uploadMaxDimension,
      maxHeight: uploadMaxDimension,
    );
    if (image == null) return;
    if ((await filterUploadable([image])).rejected > 0) {
      messageWarning(uploadTooLargeMessage);
      return;
    }
    if (!mounted) return;
    setState(() => _screenshotPath = image.path);
  }

  void _removeScreenshot() => setState(() => _screenshotPath = null);

  Future<void> _submit() async {
    final controller = context.read<FeedbackCreateController>();
    final validation = controller.validate(_messageController.text);
    setState(() => _messageError = validation.message);
    if (!validation.isValid) return;

    final result = await controller.submit(
      type: _type,
      message: _messageController.text,
      screenshotPath: _screenshotPath,
    );
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        messageComplete('Санал хүсэлт илгээгдлээ');
        if (widget.onCreated != null) {
          widget.onCreated!(value);
        } else {
          Navigator.of(context).pop(value);
        }
      case Err(:final error):
        messageError(error.display);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FeedbackCreateController>();
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(title: const Text('Санал хүсэлт илгээх')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.paddingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Төрөл', style: context.textStyles.captionMedium),
              const SizedBox(height: AppDimens.paddingSM),
              Wrap(
                spacing: AppDimens.paddingSM,
                runSpacing: AppDimens.paddingSM,
                children: FeedbackType.values.map((type) {
                  final selected = type == _type;
                  return ChoiceChip(
                    label: Text(feedbackTypeLabel(type)),
                    avatar: Icon(feedbackTypeIcon(type), size: 16),
                    selected: selected,
                    onSelected: (_) => setState(() => _type = type),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppDimens.paddingLG),
              Text('Мессеж', style: context.textStyles.captionMedium),
              const SizedBox(height: AppDimens.paddingSM),
              TextField(
                controller: _messageController,
                maxLines: 5,
                minLines: 3,
                decoration: InputDecoration(
                  hintText: 'Тайлбарлаж бичнэ үү...',
                  errorText: _messageError,
                ),
                onChanged: (_) {
                  if (_messageError != null) setState(() => _messageError = null);
                },
              ),
              const SizedBox(height: AppDimens.paddingLG),
              Text('Дэлгэцийн зураг (заавал биш)', style: context.textStyles.captionMedium),
              const SizedBox(height: AppDimens.paddingSM),
              if (_screenshotPath != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                      child: Image.file(
                        File(_screenshotPath!),
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: AppDimens.paddingXS,
                      right: AppDimens.paddingXS,
                      child: GestureDetector(
                        onTap: _removeScreenshot,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: context.colors.textPrimary.withOpacity(0.54),
                            shape: BoxShape.circle,
                          ),
                          // Fixed white, not a theme color: this sits on an
                          // opaque dark scrim over a photo thumbnail, not on
                          // themed app chrome, so it does not flip with
                          // brightness.
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                OutlinedButton.icon(
                  onPressed: _pickScreenshot,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Зураг нэмэх'),
                ),
              const SizedBox(height: AppDimens.paddingXL),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: controller.submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.accent,
                    foregroundColor: CarCareTheme.of(context).onAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                    ),
                  ),
                  child: controller.submitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: CarCareTheme.of(context).onAccent,
                          ),
                        )
                      : const Text('Илгээх'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
