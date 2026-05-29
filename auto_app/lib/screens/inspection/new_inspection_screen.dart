import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common/common_widgets.dart';
import 'inspection_result_screen.dart';

// ─── STEP 1: General Info ────────────────
class NewInspectionScreen extends StatefulWidget {
  const NewInspectionScreen({super.key});

  @override
  State<NewInspectionScreen> createState() => _NewInspectionScreenState();
}

class _NewInspectionScreenState extends State<NewInspectionScreen> {
  final _plateCtrl = TextEditingController();
  final _makeCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _vinCtrl = TextEditingController();
  final _mileageCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<NewInspectionProvider>();
    final fmt = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Шинэ оношилгоо'),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.calendar_today_outlined, size: 20),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ерөнхий мэдээлэл', style: AppTextStyles.h3),
                  const SizedBox(height: 20),

                  // Date
                  AppTextField(
                    label: 'Огноо',
                    hint: fmt.format(prov.date),
                    readOnly: true,
                    suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: prov.date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) prov.setDate(d);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Plate
                  AppTextField(
                    label: 'Тээврийн хэрэгслийн дугаар',
                    hint: 'УБ 1234 АБА',
                    controller: _plateCtrl,
                    suffixIcon: const Icon(Icons.qr_code_scanner_outlined, size: 18),
                    onChanged: prov.setPlateNumber,
                  ),
                  const SizedBox(height: 14),

                  // Make & Model
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'Марка',
                          hint: 'Toyota',
                          controller: _makeCtrl,
                          onChanged: prov.setMake,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppTextField(
                          label: 'Загвар',
                          hint: 'Prius 2016',
                          controller: _modelCtrl,
                          onChanged: prov.setModel,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // VIN
                  AppTextField(
                    label: 'VIN дугаар',
                    hint: 'JTDBR3FU8GJ123456',
                    controller: _vinCtrl,
                    onChanged: prov.setVin,
                  ),
                  const SizedBox(height: 14),

                  // Type dropdown
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Үйлчилгээний төрөл', style: AppTextStyles.captionMedium),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<InspectionType>(
                        value: prov.type,
                        decoration: const InputDecoration(),
                        items: InspectionType.values
                            .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                            .toList(),
                        onChanged: (v) => v != null ? prov.setType(v) : null,
                        style: AppTextStyles.body,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Mileage
                  AppTextField(
                    label: 'Явсан км',
                    hint: '125,430',
                    controller: _mileageCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (v) => prov.setMileage(int.tryParse(v.replaceAll(',', '')) ?? 0),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Summary preview
            if (prov.plateNumber.isNotEmpty) ...[
              AppCard(
                color: AppColors.background,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Оношилгооны дүн', style: AppTextStyles.captionMedium),
                    const SizedBox(height: 12),
                    StatCounterRow(
                      good: prov.totalGood,
                      warning: prov.totalWarning,
                      danger: prov.totalDanger,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Буцах',
                    outlined: true,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Үргэлжлүүлэх',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider.value(
                            value: prov,
                            child: const ChecklistScreen(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── STEP 2: Checklist ──────────────────
class ChecklistScreen extends StatelessWidget {
  const ChecklistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<NewInspectionProvider>();
    final section = prov.currentSectionData;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Оношилгооны үзүүлэлт'),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          // Section tabs
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SectionProgressTabs(
              titles: prov.sections.map((s) => s.title).toList(),
              current: prov.currentSection,
              onTap: (i) {
                for (int step = prov.currentSection; step < i; step++) {
                  prov.nextSection();
                }
                for (int step = prov.currentSection; step > i; step--) {
                  prov.prevSection();
                }
              },
            ),
          ),

          // Items list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppDimens.paddingMD),
              children: [
                AppCard(
                  child: Column(
                    children: section.items.map((item) {
                      final isLast = item == section.items.last;
                      return Column(
                        children: [
                          CheckItemRow(
                            item: item,
                            editable: true,
                            onStatusChanged: (status) =>
                                prov.updateItemStatus(section.id, item.id, status),
                          ),
                          if (!isLast) const Divider(height: 1),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Bottom nav
          Container(
            padding: const EdgeInsets.all(AppDimens.paddingMD),
            color: AppColors.surface,
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Буцах',
                      outlined: true,
                      onPressed: () {
                        if (prov.canGoPrev) {
                          prov.prevSection();
                        } else {
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: prov.canGoNext ? 'Үргэлжлүүлэх' : 'Дуусгах',
                      onPressed: () {
                        if (prov.canGoNext) {
                          prov.nextSection();
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChangeNotifierProvider.value(
                                value: prov,
                                child: const NoteScreen(),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── STEP 3: Notes & Photos ─────────────
class NoteScreen extends StatefulWidget {
  const NoteScreen({super.key});

  @override
  State<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends State<NoteScreen> {
  final _commentCtrl = TextEditingController();
  final _recCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<NewInspectionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Нэмэлт мэдээлэл'),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.paddingMD),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Зураг хавсаргах', style: AppTextStyles.h3),
                const SizedBox(height: 12),
                PhotoGrid(
                  urls: prov.photoUrls,
                  onAddTap: () {
                    // image_picker integration point
                    prov.addPhoto('https://via.placeholder.com/80');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Тайлбар', style: AppTextStyles.h3),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _commentCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Оношилгооны тайлбар...',
                  ),
                  onChanged: prov.setComment,
                  style: AppTextStyles.body,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Дүгнэлт', style: AppTextStyles.h3),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: prov.severity,
                  decoration: const InputDecoration(),
                  items: ['Хэвийн', 'Анхаарах', 'Засвар шаарддагатай']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => v != null ? prov.setSeverity(v) : null,
                ),
                const SizedBox(height: 12),
                Text('Зөвлөмж', style: AppTextStyles.captionMedium),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _recCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'Засварын зөвлөмж...'),
                  onChanged: prov.setRecommendation,
                  style: AppTextStyles.body,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Буцах',
                  outlined: true,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: 'Хадгалах',
                  onPressed: () {
                    final record = prov.buildRecord();
                    context.read<InspectionProvider>().addRecord(record);
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InspectionResultScreen(record: record),
                      ),
                      (route) => route.isFirst,
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
