import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/app_user.dart';
import '../../../data/repositories/trip_repository.dart';
import '../../../shared/widgets/feedback/app_toast.dart';
import '../../../shared/widgets/layout/app_sheet.dart';

Future<void> showAddMemberSheet(BuildContext context, {required int nextOrder}) =>
    showAppSheet(
      context: context,
      title: 'Adicionar participante',
      subtitle: 'A pessoa precisa já ter uma conta no app',
      builder: (_) => AddMemberSheet(nextOrder: nextOrder),
    );

class AddMemberSheet extends ConsumerStatefulWidget {
  const AddMemberSheet({super.key, required this.nextOrder});

  final int nextOrder;

  @override
  ConsumerState<AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends ConsumerState<AddMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _loading = false;
  String? _error;
  AppUser? _found;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// Procura a conta antes de adicionar, para o admin confirmar que é
  /// mesmo a pessoa certa em vez de adicionar um e-mail digitado errado.
  Future<void> _search() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
      _found = null;
    });

    try {
      final user = await ref.read(userRepositoryProvider).findByEmail(_emailController.text);
      if (!mounted) return;

      if (user == null) {
        setState(() => _error =
            'Ninguém com esse e-mail tem conta ainda. Peça para a pessoa se cadastrar primeiro.');
      } else {
        setState(() => _found = user);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Não deu para buscar: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final user = _found;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      final result = await ref.read(tripRepositoryProvider).addMemberByEmail(
            tripId: ref.read(currentTripIdProvider),
            user: user,
            order: widget.nextOrder,
          );

      if (!mounted) return;

      switch (result) {
        case AddMemberResult.added:
          Navigator.of(context).pop();
          AppToast.success(
            '${user.shortName} entrou na viagem!',
            icon: Icons.celebration_rounded,
          );
        case AddMemberResult.alreadyMember:
          setState(() {
            _loading = false;
            _error = 'Essa pessoa já participa da viagem.';
          });
        case AddMemberResult.notRegistered:
          setState(() {
            _loading = false;
            _error = 'Essa pessoa ainda não tem conta.';
          });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Não deu para adicionar: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.md, Gap.xl, Gap.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _emailController,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.search,
                    onFieldSubmitted: (_) => _search(),
                    onChanged: (_) {
                      if (_found != null || _error != null) {
                        setState(() {
                          _found = null;
                          _error = null;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'E-mail da pessoa',
                      hintText: 'amigo@email.com',
                      prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
                      suffixIcon: IconButton(
                        onPressed: _loading ? null : _search,
                        icon: const Icon(Icons.search_rounded),
                        tooltip: 'Procurar',
                      ),
                    ),
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return 'Informe o e-mail';
                      final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
                      return ok ? null : 'E-mail inválido';
                    },
                  ),

                  if (_error != null) ...[
                    Gap.vLg,
                    _Banner(
                      color: AppColors.danger,
                      icon: Icons.person_off_outlined,
                      child: Text(
                        _error!,
                        style: context.text.bodySmall?.copyWith(color: AppColors.danger),
                      ),
                    ),
                  ],

                  if (_found != null) ...[
                    Gap.vLg,
                    _Banner(
                      color: context.success,
                      icon: Icons.person_add_alt_1_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_found!.displayName,
                              style: context.text.titleSmall),
                          Text(_found!.email, style: context.text.bodySmall),
                        ],
                      ),
                    ),
                  ],

                  Gap.vXl,
                  Text(
                    'Todo participante gerencia a viagem por completo: roteiro, '
                    'contas e mural. Só o administrador adiciona e remove gente.',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
        SheetActions(
          primaryLabel: _found == null ? 'Procurar' : 'Adicionar à viagem',
          onPrimary: _found == null ? _search : _add,
          secondaryLabel: 'Cancelar',
          onSecondary: () => Navigator.of(context).pop(),
          isLoading: _loading,
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.icon, required this.child});

  final Color color;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: Radii.brSm,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          Gap.hMd,
          Expanded(child: child),
        ],
      ),
    );
  }
}
