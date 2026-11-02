import 'package:flutter/material.dart';

const dotColors = [
  Color(0xFFFF3B30),
  Color(0xFFFF9500),
  Color(0xFFFFCC00),
  Color(0xFF34C759),
  Color(0xFF00E5FF),
  Color(0xFF2F7BFF),
  Color(0xFFB36BFF),
  Color(0xFFFF4FA3),
  Color(0xFFFFFFFF),
];

const backgroundColors = [
  Color(0xFF000000),
  Color(0xFF0A0A0A),
  Color(0xFF101828),
  Color(0xFF1A0F0A),
  Color(0xFF0B1A10),
  Color(0xFF2A2A2A),
];

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class Hint extends StatelessWidget {
  const Hint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class ColorSwatches extends StatelessWidget {
  const ColorSwatches({
    super.key,
    required this.colors,
    required this.selected,
    required this.onSelected,
  });

  final List<Color> colors;
  final Color? selected;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.primary;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in colors)
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => onSelected(c),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: c == selected ? outline : Colors.white24,
                  width: c == selected ? 3 : 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class LabeledSlider extends StatelessWidget {
  const LabeledSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
    this.divisions,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double) display;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(min, max);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label),
              const Spacer(),
              Text(display(v), style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          Slider(
            value: v,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// A wrapping row of single-choice chips; fits narrow side panels better
/// than a segmented button.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<(T, IconData, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (value, icon, label) in options)
          ChoiceChip(
            avatar: Icon(icon, size: 18),
            label: Text(label),
            selected: value == selected,
            showCheckmark: false,
            onSelected: (_) => onSelected(value),
          ),
      ],
    );
  }
}

/// A titled group of settings that folds away, so a long editor reads as a
/// short list of topics; while folded, [summary] tells what is set inside.
///
/// Which groups are open is remembered by [id] across editors, so moving
/// to another scene keeps the same groups open.
class SettingsGroup extends StatefulWidget {
  const SettingsGroup({
    super.key,
    required this.id,
    required this.icon,
    required this.title,
    required this.summary,
    required this.children,
    this.initiallyOpen = false,
    this.trailing,
  });

  final String id;
  final IconData icon;
  final String title;
  final String summary;
  final List<Widget> children;
  final bool initiallyOpen;

  /// Shown next to the summary, e.g. a color dot.
  final Widget? trailing;

  static final _open = <String, bool>{};

  @override
  State<SettingsGroup> createState() => _SettingsGroupState();
}

class _SettingsGroupState extends State<SettingsGroup> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final open = SettingsGroup._open[widget.id] ?? widget.initiallyOpen;
    return Card(
      margin: const EdgeInsets.only(top: 10),
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // No lines above and below an open group; the card frames it.
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('group-${widget.id}'),
          initiallyExpanded: open,
          onExpansionChanged: (v) => SettingsGroup._open[widget.id] = v,
          leading: Icon(widget.icon),
          title: Text(widget.title, style: theme.textTheme.titleMedium),
          subtitle: Row(
            children: [
              if (widget.trailing != null) ...[
                widget.trailing!,
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  widget.summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: widget.children,
        ),
      ),
    );
  }
}

/// A small filled circle in [color] (or a rainbow), for summaries.
class ColorDot extends StatelessWidget {
  const ColorDot({super.key, required this.color, this.rainbow = false});

  final Color color;
  final bool rainbow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: rainbow ? null : color,
        gradient: rainbow ? rainbowGradient : null,
        border: Border.all(color: Colors.white24),
      ),
    );
  }
}

const rainbowGradient = SweepGradient(
  colors: [
    Color(0xFFFF3B30),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF00E5FF),
    Color(0xFF2F7BFF),
    Color(0xFFB36BFF),
    Color(0xFFFF3B30),
  ],
);
