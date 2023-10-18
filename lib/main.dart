import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => Counter()),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jupyter代码统计'),
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.15),
      ),
      body: const CountTable(),
      floatingActionButton: const SelectFileActions(),
    );
  }
}

class SelectFileActions extends StatelessWidget {
  const SelectFileActions({
    super.key,
  });

  void countNotebook(BuildContext context, File file) {
    var data = file.readAsStringSync();
    var data1 = jsonDecode(data);
    int sumLines = 0;
    if (data1 is Map) {
      var cells = data1["cells"];
      if (cells is List) {
        for (var cell in cells) {
          if (cell["cell_type"] == "code" && cell["source"] is List) {
            sumLines += (cell["source"] as List).length;
          }
        }
      }
    }
    Provider.of<Counter>(context, listen: false)
        .addNotebook(p.basename(file.path), file.path, sumLines);
  }

  Future<void> handleFileSelected(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['ipynb']);

    if (result != null) {
      File file = File(result.files.single.path!);
      if (context.mounted) {
        countNotebook(context, file);
      }
    }
  }

  Future<void> handleDirectorySelected(BuildContext context) async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      final files = Glob(p.join(selectedDirectory, "*.ipynb"));
      if (context.mounted) {
        for (var entry in files.listSync()) {
          countNotebook(context, File(entry.path));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      FloatingActionButton(
          child: const Icon(Icons.file_open),
          onPressed: () => handleFileSelected(context)),
      const SizedBox(width: 16),
      FloatingActionButton(
          child: const Icon(Icons.folder_open),
          onPressed: () => handleDirectorySelected(context))
    ]);
  }
}

class CountTable extends StatelessWidget {
  const CountTable({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    var notebooks = context.watch<Counter>().notebooks;
    var sumLines = context.watch<Counter>().sumLines;
    return Center(
        child: ListView(
      children: [
        DataTable(
          columns: const [
            DataColumn(
                label: Expanded(
              child: Text(
                '',
              ),
            )),
            DataColumn(
                label: Expanded(
              child: Text(
                '名称',
              ),
            )),
            DataColumn(
                label: Expanded(
              child: Text(
                '路径',
              ),
            )),
            DataColumn(
                label: Expanded(
              child: Text(
                '行数',
              ),
            ))
          ],
          rows: staticsRows(notebooks, sumLines),
        ),
      ],
    ));
  }

  DataRow notebookCell(String name, String path, int lines) {
    return DataRow(cells: [
      const DataCell(Text('')),
      DataCell(Text(name)),
      DataCell(Text(path)),
      DataCell(Text('$lines')),
    ]);
  }

  DataRow sumCell(int sumLines) {
    return DataRow(cells: [
      const DataCell(Text('总计')),
      const DataCell(Text('')),
      const DataCell(Text('')),
      DataCell(Text('$sumLines')),
    ]);
  }

  List<DataRow> staticsRows(List<NotebookState> notebooks, int sumLines) {
    List<DataRow> rows = [];
    for (var notebook in notebooks) {
      rows.add(notebookCell(notebook.name, notebook.path, notebook.lines));
    }
    rows.add(sumCell(sumLines));
    return rows;
  }
}

class NotebookState {
  String name;
  String path;
  int lines;
  NotebookState(this.name, this.path, this.lines);
}

class Counter with ChangeNotifier {
  final List<NotebookState> _notebooks = [];

  List<NotebookState> get notebooks => _notebooks;
  int get sumLines => _sumLines();

  void addNotebook(String name, String path, int lines) {
    _notebooks.add(NotebookState(name, path, lines));
    notifyListeners();
  }

  int _sumLines() {
    int sum = 0;
    for (var element in notebooks) {
      sum += element.lines;
    }
    return sum;
  }
}
