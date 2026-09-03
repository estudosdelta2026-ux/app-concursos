import 'package:flutter/material.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'dart:io';

void main() {
  runApp(const ConcursoApp());
}

// Modelo simples para cada tópico do edital
class TopicoEdital {
  String titulo;
  bool concluido;

  TopicoEdital({required this.titulo, this.concluido = false});
}

class ConcursoApp extends StatelessWidget {
  const ConcursoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aprovado Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  
  // Dados de Estudo
  int _questoesResolvidas = 0;
  int _metaQuestoes = 50;
  int _minutosEstudados = 0;
  int _metaMinutosDiaria = 240;

  // Lista de Tópicos do Edital
  List<TopicoEdital> _cronograma = [];

  // Lógica do Pomodoro
  Timer? _timer;
  int _secondsRemaining = 25 * 60;
  bool _isRunning = false;

  void _startTimer() {
    if (_isRunning) return;
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _stopTimer();
        setState(() {
          _minutosEstudados += 25;
          _secondsRemaining = 25 * 60;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bloco Pomodoro concluído! +25 min salvos.')),
        );
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _stopTimer();
    setState(() => _secondsRemaining = 25 * 60);
  }

  // Importador de Excel com suporte a Progresso
  Future<void> _importarExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result != null && result.files.single.path != null) {
      var bytes = File(result.files.single.path!).readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);

      List<TopicoEdital> novosTopicos = [];
      for (var table in excel.tables.keys) {
        for (var row in excel.tables[table]!.rows) {
          if (row.isNotEmpty && row[0] != null) {
            novosTopicos.add(TopicoEdital(titulo: row[0]!.value.toString()));
          }
        }
      }

      setState(() {
        _cronograma = novosTopicos;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${novosTopicos.length} tópicos importados com sucesso!')),
        );
      }
    }
  }

  // Cálculo da porcentagem de progresso
  double _calcularProgressoEdital() {
    if (_cronograma.isEmpty) return 0.0;
    int concluidos = _cronograma.where((item) => item.concluido).length;
    return concluidos / _cronograma.length;
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildPomodoroTab(),
      _buildMetasTab(),
      _buildEditalTab(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Aprovado Pro - Estudos')),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.timer), label: 'Pomodoro'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Metas'),
          BottomNavigationBarItem(icon: Icon(Icons.checklist), label: 'Edital'),
        ],
      ),
    );
  }

  Widget _buildPomodoroTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _formatTime(_secondsRemaining),
            style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _isRunning ? _stopTimer : _startTimer,
                child: Text(_isRunning ? 'Pausar' : 'Iniciar'),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _resetTimer,
                child: const Text('Resetar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetasTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Progresso Diário', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Text('Horas Estudadas: ${(_minutosEstudados / 60).toStringAsFixed(1)} h / ${(_metaMinutosDiaria / 60).toStringAsFixed(1)} h'),
          LinearProgressIndicator(value: _minutosEstudados / _metaMinutosDiaria),
          const SizedBox(height: 20),
          Text('Questões Resolvidas: $_questoesResolvidas / $_metaQuestoes'),
          LinearProgressIndicator(value: _questoesResolvidas / _metaQuestoes),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => setState(() => _questoesResolvidas += 10),
            child: const Text('+10 Questões Concluídas'),
          ),
        ],
      ),
    );
  }

  Widget _buildEditalTab() {
    double progresso = _calcularProgressoEdital();
    int porcentagem = (progresso * 100).round();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed: _importarExcel,
            icon: const Icon(Icons.file_upload),
            label: const Text('Importar Edital (Excel .xlsx)'),
          ),
          const SizedBox(height: 20),
          if (_cronograma.isNotEmpty) ...[
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Progresso do Edital', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('$porcentagem%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progresso,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Expanded(
            child: _cronograma.isEmpty
                ? const Center(child: Text('Nenhum edital importado ainda.'))
                : ListView.builder(
                    itemCount: _cronograma.length,
                    itemBuilder: (context, index) {
                      final item = _cronograma[index];
                      return CheckboxListTile(
                        title: Text(
                          item.titulo,
                          style: TextStyle(
                            decoration: item.concluido ? TextDecoration.lineThrough : null,
                            color: item.concluido ? Colors.grey : Colors.black,
                          ),
                        ),
                        value: item.concluido,
                        onChanged: (bool? valor) {
                          setState(() {
                            item.concluido = valor ?? false;
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
