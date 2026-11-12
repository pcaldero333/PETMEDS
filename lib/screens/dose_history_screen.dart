import 'package:flutter/material.dart';

import '../models/dose_history.dart';
import '../services/pending_dose_service.dart';

class DoseHistoryScreen extends StatefulWidget {
  const DoseHistoryScreen({super.key});

  @override
  State<DoseHistoryScreen> createState() => _DoseHistoryScreenState();
}

class _DoseHistoryScreenState extends State<DoseHistoryScreen> {
  final PendingDoseService _pendingDoseService = PendingDoseService();

  List<DoseHistory> _history = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _pendingDoseService.getDoseHistory();

      if (!mounted) return;

      setState(() {
        _history = history;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'No fue posible cargar el historial.';
      });
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();

    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day/$month/$year  $hour:$minute';
  }

  String _statusText(String status) {
    switch (status) {
      case 'ADMINISTERED':
        return 'Administrada';
      case 'OMITTED':
        return 'Omitida';
      case 'MISSED':
        return 'Perdida';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ADMINISTERED':
        return Colors.green;
      case 'OMITTED':
        return Colors.orange;
      case 'MISSED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'ADMINISTERED':
        return Icons.check_circle;
      case 'OMITTED':
        return Icons.remove_circle;
      case 'MISSED':
        return Icons.warning;
      default:
        return Icons.help;
    }
  }

  String _doseText(DoseHistory dose) {
    if (dose.doseAmount == null) {
      return 'Dosis no especificada';
    }

    final amount = dose.doseAmount! % 1 == 0
        ? dose.doseAmount!.toInt().toString()
        : dose.doseAmount!.toString();

    if (dose.doseUnit == null || dose.doseUnit!.isEmpty) {
      return amount;
    }

    return '$amount ${dose.doseUnit}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de dosis')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: Colors.red, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_history.isEmpty) {
      return const Center(
        child: Text(
          'No hay registros en el historial.',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final dose = _history[index];

          final statusColor = _statusColor(dose.status);

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _statusIcon(dose.status),
                        color: statusColor,
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          dose.medicineName ?? 'Medicamento desconocido',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        _statusText(dose.status),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'Mascota: ${dose.patientName ?? 'Desconocida'}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    'Dosis: ${_doseText(dose)}',
                    style: const TextStyle(fontSize: 15),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    'Programada: ${_formatDateTime(dose.scheduledDateTime)}',
                    style: const TextStyle(fontSize: 14),
                  ),

                  if (dose.administeredDateTime != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      'Administrada: '
                      '${_formatDateTime(dose.administeredDateTime!)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
