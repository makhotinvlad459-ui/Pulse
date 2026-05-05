import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api_client.dart';
import '../../../providers/locale_provider.dart';
import 'package:frontend/l10n/app_localizations.dart';

class CounterpartyInput extends ConsumerStatefulWidget {
  final int companyId;
  final TextEditingController controller;
  final String? initialValue;
  final void Function(String)? onChanged;

  const CounterpartyInput({
    super.key,
    required this.companyId,
    required this.controller,
    this.initialValue,
    this.onChanged,
  });

  @override
  ConsumerState<CounterpartyInput> createState() => _CounterpartyInputState();
}

class _CounterpartyInputState extends ConsumerState<CounterpartyInput> {
  List<String> _suggestions = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      widget.controller.text = widget.initialValue!;
    }
  }

  Future<void> _loadCounterparties() async {
    if (_suggestions.isNotEmpty) return;
    setState(() => _loading = true);
    final api = ApiClient();
    try {
      final list = await api.getCounterparties(widget.companyId);
      setState(() {
        _suggestions = list;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) async {
        await _loadCounterparties();
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        return _suggestions.where((option) =>
            option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
      },
      onSelected: (String selection) {
        widget.controller.text = selection;
        widget.onChanged?.call(selection);
      },
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        widget.controller.addListener(() {
          if (textEditingController.text != widget.controller.text) {
            textEditingController.text = widget.controller.text;
          }
        });
        textEditingController.addListener(() {
          if (widget.controller.text != textEditingController.text) {
            widget.controller.text = textEditingController.text;
          }
        });
        return TextField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: t.counterpartyOptional,
            labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
            border: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.outline)),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.outline)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.primary)),
            suffixIcon: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : null,
          ),
          style: TextStyle(color: colorScheme.onSurface),
          onChanged: (value) {
            widget.controller.text = value;
            widget.onChanged?.call(value);
          },
        );
      },
    );
  }
}