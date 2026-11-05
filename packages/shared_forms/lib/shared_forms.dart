library;

import 'package:flutter/material.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';

class InspectionChecklist extends StatelessWidget {
  const InspectionChecklist({
    super.key,
    required this.template,
    required this.answers,
    required this.onChanged,
    this.readOnly = false,
  });
  final ChecklistTemplate template;
  final Map<String, InspectionAnswer> answers;
  final ValueChanged<Map<String, InspectionAnswer>> onChanged;
  final bool readOnly;
  static String label(AnswerChoice choice) => switch (choice) {
    AnswerChoice.yes => 'Yes',
    AnswerChoice.no => 'No',
    AnswerChoice.unknown => 'Unknown',
    AnswerChoice.notApplicable => 'N/A',
  };
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < template.questions.length; index++)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _QuestionCard(
            key: ValueKey(template.questions[index].id),
            question: template.questions[index],
            index: index,
            answer: answers[template.questions[index].id],
            readOnly: readOnly,
            onChanged: (answer) =>
                onChanged({...answers, template.questions[index].id: answer}),
          ),
        ),
    ],
  );
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    super.key,
    required this.question,
    required this.index,
    required this.answer,
    required this.onChanged,
    required this.readOnly,
  });
  final ChecklistQuestion question;
  final int index;
  final InspectionAnswer? answer;
  final ValueChanged<InspectionAnswer> onChanged;
  final bool readOnly;
  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${(index + 1).toString().padLeft(2, '0')}   /   ${question.required ? 'REQUIRED' : 'OPTIONAL'}',
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w700,
            color: TankColors.muted,
          ),
        ),
        const SizedBox(height: 12),
        Text(question.label, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          question.rationale,
          style: const TextStyle(color: TankColors.muted),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final choice in AnswerChoice.values)
              ChoiceChip(
                label: Text(InspectionChecklist.label(choice)),
                selected: answer?.choice == choice,
                onSelected: readOnly
                    ? null
                    : (_) => onChanged(
                        InspectionAnswer(choice, note: answer?.note ?? ''),
                      ),
                selectedColor: choice == AnswerChoice.yes
                    ? TankColors.caution
                    : TankColors.mint,
                backgroundColor: Colors.white.withValues(alpha: .75),
                tooltip:
                    '${question.label} ${InspectionChecklist.label(choice)}',
              ),
          ],
        ),
        if (answer?.choice == AnswerChoice.yes ||
            answer?.choice == AnswerChoice.unknown ||
            (answer?.note.isNotEmpty ?? false)) ...[
          const SizedBox(height: 16),
          TextFormField(
            initialValue: answer?.note ?? '',
            readOnly: readOnly,
            maxLength: 1000,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Observation note (optional)',
              hintText: 'Describe what you can observe.',
            ),
            onChanged: (note) =>
                onChanged(InspectionAnswer(answer!.choice, note: note)),
          ),
        ],
      ],
    ),
  );
}
