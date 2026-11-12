import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class TreatmentHistoryScreen extends StatefulWidget {
  const TreatmentHistoryScreen({super.key});

  @override
  State<TreatmentHistoryScreen> createState() => _TreatmentHistoryScreenState();
}

class _TreatmentHistoryScreenState extends State<TreatmentHistoryScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  static const Color _azul = Color(0xFF163B52);
  static const Color _verde = Color(0xFF287C68);
  static const Color _fondo = Color(0xFFF3F7F5);

  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _treatments = [];
  List<Map<String, dynamic>> _history = [];

  int? _selectedPatientId;
  int? _selectedTreatmentId;
  Map<String, dynamic>? _selectedTreatment;

  bool _loadingPatients = true;
  bool _loadingTreatments = false;
  bool _loadingHistory = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  // ------------------------------------------------------------
  // CARGAR MASCOTAS
  // ------------------------------------------------------------

  Future<void> _loadPatients() async {
    setState(() {
      _loadingPatients = true;
      _errorMessage = null;
    });

    try {
      final db = await _dbHelper.database;
      final result = await db.query('patients', orderBy: 'name ASC');

      if (!mounted) return;

      setState(() {
        _patients = result;
        _loadingPatients = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingPatients = false;
        _errorMessage = 'No fue posible cargar las mascotas.';
      });
    }
  }

  // ------------------------------------------------------------
  // CARGAR TRATAMIENTOS DE LA MASCOTA
  // ------------------------------------------------------------

  Future<void> _loadTreatments(int patientId) async {
    setState(() {
      _loadingTreatments = true;
      _treatments = [];
      _selectedTreatmentId = null;
      _selectedTreatment = null;
      _history = [];
      _errorMessage = null;
    });

    try {
      final db = await _dbHelper.database;

      final result = await db.rawQuery(
        '''
        SELECT
          t.id,
          t.patientId,
          t.medicineId,
          t.startDate,
          t.endDate,
          t.frequencyHours,
          t.doseAmount,
          t.doseUnit,
          t.totalDoses,
          t.active,
          m.name AS medicineName
        FROM treatments t
        INNER JOIN medicines m
          ON m.id = t.medicineId
        WHERE t.patientId = ?
        ORDER BY t.startDate DESC
      ''',
        [patientId],
      );

      if (!mounted) return;

      setState(() {
        _treatments = result;
        _loadingTreatments = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingTreatments = false;
        _errorMessage = 'No fue posible cargar los tratamientos.';
      });
    }
  }

  // ------------------------------------------------------------
  // SELECCIONAR TRATAMIENTO
  // ------------------------------------------------------------

  Future<void> _selectTreatment() async {
    if (_treatments.isEmpty) return;

    final selectedId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.70,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Seleccionar tratamiento',
                    style: TextStyle(
                      color: _azul,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_treatments.length} tratamiento(s) encontrado(s)',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _treatments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final treatment = _treatments[index];
                        final id = treatment['id'] as int;
                        final selected = id == _selectedTreatmentId;

                        return Material(
                          color: selected
                              ? _verde.withValues(alpha: 0.08)
                              : _fondo,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: () => Navigator.pop(sheetContext, id),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? _verde
                                      : Colors.grey.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: _verde.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.medication_outlined,
                                      color: _verde,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          treatment['medicineName']
                                                  ?.toString() ??
                                              'Medicamento',
                                          style: const TextStyle(
                                            color: _azul,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          _frequencyText(
                                            treatment['frequencyHours'],
                                          ),
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${_formatDate(treatment['startDate']?.toString())}  →  '
                                          '${_formatDate(treatment['endDate']?.toString())}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (selected)
                                    const Icon(
                                      Icons.check_circle,
                                      color: _verde,
                                    )
                                  else
                                    Icon(
                                      Icons.chevron_right,
                                      color: Colors.grey.shade500,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || selectedId == null) return;

    setState(() {
      _selectedTreatmentId = selectedId;
    });

    await _loadHistory(selectedId);
  }

  // ------------------------------------------------------------
  // CARGAR HISTORIAL
  // ------------------------------------------------------------

  Future<void> _loadHistory(int treatmentId) async {
    setState(() {
      _loadingHistory = true;
      _history = [];
      _selectedTreatment = null;
      _errorMessage = null;
    });

    try {
      final db = await _dbHelper.database;

      final treatmentResult = await db.rawQuery(
        '''
        SELECT
          t.*,
          m.name AS medicineName,
          p.name AS patientName
        FROM treatments t
        INNER JOIN medicines m ON m.id = t.medicineId
        INNER JOIN patients p ON p.id = t.patientId
        WHERE t.id = ?
        LIMIT 1
      ''',
        [treatmentId],
      );

      final historyResult = await db.query(
        'dose_history',
        where: 'treatmentId = ?',
        whereArgs: [treatmentId],
        orderBy: 'scheduledDateTime ASC',
      );

      if (!mounted) return;

      setState(() {
        _selectedTreatment = treatmentResult.isNotEmpty
            ? treatmentResult.first
            : null;
        _history = historyResult;
        _loadingHistory = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingHistory = false;
        _errorMessage = 'No fue posible consultar el historial de dosis.';
      });
    }
  }

  // ------------------------------------------------------------
  // FORMATO DE FECHAS Y DATOS
  // ------------------------------------------------------------

  String _formatDateTime(String? value) {
    if (value == null || value.isEmpty) return '-';

    final dateTime = DateTime.tryParse(value);
    if (dateTime == null) return '-';

    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return '-';

    final dateTime = DateTime.tryParse(value);
    if (dateTime == null) return '-';

    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');

    return '$day/$month/${dateTime.year}';
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '-';

    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String _frequencyText(dynamic value) {
    final hours = value is int ? value : int.tryParse(value?.toString() ?? '');

    if (hours == null || hours <= 0) return '-';

    if (hours < 24) return 'Cada $hours h';

    if (hours % 24 == 0) {
      final days = hours ~/ 24;
      if (days == 1) return 'Cada 24 h';
      return 'Cada $days días';
    }

    return 'Cada $hours h';
  }

  String _doseText(Map<String, dynamic> treatment) {
    final amount = treatment['doseAmount'];
    final unit = treatment['doseUnit'];

    if (amount == null) return '-';

    final String amountText;
    if (amount is num && amount % 1 == 0) {
      amountText = amount.toInt().toString();
    } else {
      amountText = amount.toString();
    }

    if (unit == null || unit.toString().isEmpty) {
      return amountText;
    }

    return '$amountText ${unit.toString()}';
  }

  // ------------------------------------------------------------
  // CONTADORES Y ESTADOS
  // ------------------------------------------------------------

  int _countStatus(String status) =>
      _history.where((dose) => dose['status'] == status).length;

  int get _administered => _countStatus('ADMINISTERED');
  int get _omitted => _countStatus('OMITTED');
  int get _missed => _countStatus('MISSED');

  int get _registered => _administered + _omitted + _missed;

  int _scheduledDoses(Map<String, dynamic> treatment) {
    final startText = treatment['startDate']?.toString();
    final endText = treatment['endDate']?.toString();

    if (startText == null || endText == null) return 0;

    final start = DateTime.tryParse(startText);
    final end = DateTime.tryParse(endText);

    if (start == null || end == null) return 0;

    final frequency = treatment['frequencyHours'];
    final hours = frequency is int
        ? frequency
        : int.tryParse(frequency?.toString() ?? '');

    if (hours == null || hours <= 0) return 0;
    if (end.isBefore(start)) return 0;

    final difference = end.difference(start).inMinutes;
    final interval = hours * 60;

    return (difference ~/ interval) + 1;
  }

  String _statusText(String? status) {
    switch (status) {
      case 'ADMINISTERED':
        return 'Dada';
      case 'OMITTED':
        return 'Omitida';
      case 'MISSED':
        return 'Perdida';
      default:
        return status ?? '-';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'ADMINISTERED':
        return const Color(0xFF287C68);
      case 'OMITTED':
        return const Color(0xFFB87519);
      case 'MISSED':
        return const Color(0xFFC74747);
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'ADMINISTERED':
        return Icons.check_circle;
      case 'OMITTED':
        return Icons.remove_circle;
      case 'MISSED':
        return Icons.warning_rounded;
      default:
        return Icons.help_outline;
    }
  }

  // ------------------------------------------------------------
  // COMPONENTES VISUALES
  // ------------------------------------------------------------

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _verde, size: 21),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: _azul,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Filtros de consulta', Icons.filter_alt_outlined),
          const SizedBox(height: 18),

          const Text(
            'Mascota',
            style: TextStyle(color: _azul, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          DropdownButtonFormField<int>(
            value: _selectedPatientId,
            isExpanded: true,
            decoration: _inputDecoration(
              hint: 'Seleccione una mascota',
              icon: Icons.pets_outlined,
            ),
            hint: const Text('Seleccione una mascota'),
            items: _patients.map((patient) {
              final id = patient['id'] as int;

              return DropdownMenuItem<int>(
                value: id,
                child: Text(
                  patient['name']?.toString() ?? 'Sin nombre',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                _selectedPatientId = value;
              });

              _loadTreatments(value);
            },
          ),

          const SizedBox(height: 18),

          const Text(
            'Tratamiento',
            style: TextStyle(color: _azul, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          InkWell(
            onTap: _treatments.isEmpty || _loadingTreatments
                ? null
                : _selectTreatment,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _fondo,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _selectedTreatmentId != null
                      ? _verde
                      : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.medication_outlined, color: _verde),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _loadingTreatments
                        ? const Text('Cargando tratamientos...')
                        : _selectedTreatment == null
                        ? Text(
                            _selectedPatientId == null
                                ? 'Seleccione una mascota primero'
                                : _treatments.isEmpty
                                ? 'No hay tratamientos para esta mascota'
                                : 'Seleccione un tratamiento',
                            style: TextStyle(color: Colors.grey.shade600),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedTreatment!['medicineName']
                                        ?.toString() ??
                                    'Medicamento',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _azul,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _frequencyText(
                                  _selectedTreatment!['frequencyHours'],
                                ),
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${_formatDate(_selectedTreatment!['startDate']?.toString())} → '
                                '${_formatDate(_selectedTreatment!['endDate']?.toString())}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(width: 8),
                  if (_loadingTreatments)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.keyboard_arrow_down_rounded, color: _azul),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6ECE9)),
        boxShadow: [
          BoxShadow(
            color: _azul.withValues(alpha: 0.045),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: _verde),
      filled: true,
      fillColor: _fondo,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _verde, width: 1.5),
      ),
    );
  }

  // ------------------------------------------------------------
  // RESUMEN DEL TRATAMIENTO
  // ------------------------------------------------------------

  Widget _buildTreatmentSummary() {
    if (_loadingHistory) {
      return _panel(
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: CircularProgressIndicator(color: _verde)),
        ),
      );
    }

    if (_selectedTreatment == null) {
      return _panel(
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: _verde.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_rounded, size: 30, color: _verde),
            ),
            const SizedBox(height: 12),
            const Text(
              'Consulta el historial de dosis',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _azul,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Selecciona una mascota y luego un tratamiento para ver su resumen y los registros.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.4),
            ),
          ],
        ),
      );
    }

    final treatment = _selectedTreatment!;
    final scheduled = _scheduledDoses(treatment);

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Resumen del tratamiento', Icons.assignment_outlined),
          const SizedBox(height: 18),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _azul,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.medication_rounded,
                    color: Colors.white,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        treatment['medicineName']?.toString() ?? 'Medicamento',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mascota: ${treatment['patientName']?.toString() ?? '-'}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _detailRow(
            Icons.calendar_today_outlined,
            'Inicio',
            _formatDateTime(treatment['startDate']?.toString()),
          ),
          _detailRow(
            Icons.event_available_outlined,
            'Finalización',
            _formatDateTime(treatment['endDate']?.toString()),
          ),
          _detailRow(
            Icons.schedule_rounded,
            'Frecuencia',
            _frequencyText(treatment['frequencyHours']),
          ),
          _detailRow(Icons.medication_outlined, 'Dosis', _doseText(treatment)),

          const SizedBox(height: 18),

          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 8.0;
              final itemWidth = (constraints.maxWidth - spacing) / 2;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _buildCounter(
                      'PROGRAMADAS',
                      scheduled,
                      const Color(0xFF526B7A),
                      Icons.event_note_outlined,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildCounter(
                      'DADAS',
                      _administered,
                      _verde,
                      Icons.check_circle_outline,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildCounter(
                      'OMITIDAS',
                      _omitted,
                      const Color(0xFFB87519),
                      Icons.remove_circle_outline,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildCounter(
                      'PERDIDAS',
                      _missed,
                      const Color(0xFFC74747),
                      Icons.warning_amber_rounded,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 14),

          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Registros generados: $_registered',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: _verde),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: _azul, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounter(String title, int value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 7),
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // DETALLE DE DOSIS
  // ------------------------------------------------------------

  Widget _buildHistory() {
    if (_selectedTreatmentId == null || _loadingHistory) {
      return const SizedBox.shrink();
    }

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Detalle de dosis', Icons.list_alt_rounded),
          const SizedBox(height: 6),
          Text(
            '${_history.length} registro(s) en el historial',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 16),

          if (_history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 42,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Todavía no existen registros para este tratamiento.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._history.map(_buildDoseCard),
        ],
      ),
    );
  }

  Widget _buildDoseCard(Map<String, dynamic> dose) {
    final scheduledText = dose['scheduledDateTime']?.toString();
    final scheduled = DateTime.tryParse(scheduledText ?? '');
    final status = dose['status']?.toString();

    final administeredText = dose['administeredDateTime']?.toString();
    final administered = administeredText == null || administeredText.isEmpty
        ? null
        : DateTime.tryParse(administeredText);

    final color = _statusColor(status);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5EBE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                      color: _verde,
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        _formatDate(scheduledText),
                        style: const TextStyle(
                          color: _azul,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon(status), color: color, size: 15),
                    const SizedBox(width: 5),
                    Text(
                      _statusText(status),
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _doseTimeInfo(
                  'Hora programada',
                  _formatTime(scheduled),
                  Icons.schedule_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _doseTimeInfo(
                  'Hora real',
                  _formatTime(administered),
                  Icons.check_circle_outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _doseTimeInfo(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: _verde),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: _azul,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // PANTALLA PRINCIPAL
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _azul,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Historial de dosis',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _loadingPatients
          ? const Center(child: CircularProgressIndicator(color: _verde))
          : RefreshIndicator(
              color: _verde,
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_errorMessage != null) ...[
                          _buildError(),
                          const SizedBox(height: 16),
                        ],
                        _buildFilters(),
                        const SizedBox(height: 18),
                        _buildTreatmentSummary(),
                        const SizedBox(height: 18),
                        _buildHistory(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEEE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7B7B7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFC74747)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage ?? 'Ocurrió un error.',
              style: const TextStyle(color: Color(0xFF9E3030)),
            ),
          ),
          IconButton(
            tooltip: 'Reintentar',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, color: Color(0xFFC74747)),
          ),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    if (_selectedPatientId == null) {
      await _loadPatients();
      return;
    }

    await _loadTreatments(_selectedPatientId!);

    if (!mounted) return;

    final selectedId = _selectedTreatmentId;
    if (selectedId != null) {
      await _loadHistory(selectedId);
    }
  }
}
