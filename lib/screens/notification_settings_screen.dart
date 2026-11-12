import 'package:flutter/material.dart';

import '../services/alarm_service.dart';
import '../services/parameter_service.dart';
import '../services/alarm_bootstrap_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final ParameterService _parameterService = ParameterService();

  bool _notificationsEnabled = true;
  int _postponeMinutes = 15;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await _parameterService.areNotificationsEnabled();

    final postpone = await _parameterService.getPostponeMinutes();

    if (!mounted) return;

    setState(() {
      _notificationsEnabled = enabled;
      _postponeMinutes = postpone;
      _loading = false;
    });
  }

  Future<void> _setNotificationsEnabled(bool enabled) async {
    await _parameterService.setNotificationsEnabled(enabled);

    if (!enabled) {
      await AlarmService.instance.cancelAllAlarms();
    } else {
      final granted = await AlarmService.instance.requestPermissions();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Concede los permisos de notificaciones y alarmas exactas en Ajustes del sistema.',
            ),
          ),
        );
      }
    }

    AlarmBootstrapService.instance.resetMonitorState();
    if (enabled) {
      await AlarmBootstrapService.instance.refresh();
    }

    if (!mounted) return;

    setState(() {
      _notificationsEnabled = enabled;
    });
  }

  Future<void> _setPostponeMinutes(int minutes) async {
    await _parameterService.setPostponeMinutes(minutes);

    if (!mounted) return;

    setState(() {
      _postponeMinutes = minutes;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notificaciones'), centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_outlined),
                  title: const Text('Notificaciones'),
                  subtitle: Text(
                    _notificationsEnabled
                        ? 'Las notificaciones están activadas'
                        : 'Las notificaciones están desactivadas',
                  ),
                  value: _notificationsEnabled,
                  onChanged: _setNotificationsEnabled,
                ),

                const Divider(height: 1),

                ListTile(
                  leading: const Icon(Icons.snooze_outlined),
                  title: const Text('Tiempo para posponer'),
                  subtitle: Text('$_postponeMinutes minutos'),
                  trailing: const Icon(Icons.chevron_right),
                  enabled: _notificationsEnabled,
                  onTap: _notificationsEnabled ? _showPostponeOptions : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPostponeOptions() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tiempo para posponer',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              _postponeOption(5),
              _postponeOption(10),
              _postponeOption(15),
              _postponeOption(30),

              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      await _setPostponeMinutes(selected);
    }
  }

  Widget _postponeOption(int minutes) {
    return ListTile(
      title: Text('$minutes minutos'),
      trailing: _postponeMinutes == minutes ? const Icon(Icons.check) : null,
      onTap: () {
        Navigator.of(context).pop(minutes);
      },
    );
  }
}
