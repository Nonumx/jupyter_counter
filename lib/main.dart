import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;
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
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jupyter Counter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const CounterViewer(),
    );
  }
}

class CounterViewer extends StatefulWidget {
  const CounterViewer({
    super.key,
  });

  @override
  State<CounterViewer> createState() => _CounterViewerState();
}

class JupyterNotebookInfo {
  final String fileName;
  final String filePath;
  final int lineCount;

  JupyterNotebookInfo(this.fileName, this.filePath, this.lineCount);
}

class _CounterViewerState extends State<CounterViewer> {
  int _sumLineCount = 0;
  final List<JupyterNotebookInfo> _notebooks = [];

  Future<void> readJupyterNotebook(String filePath) async {
    // 检测是否已经读取过这个文件
    for (final notebook in _notebooks) {
      if (notebook.filePath == filePath) {
        return;
      }
    }
    final fileContent = await File(filePath).readAsString();
    final fileJson = jsonDecode(fileContent);
    final fileCells = fileJson['cells'] as List?;
    if (fileCells == null) {
      return;
    }
    int lineCount = 0;
    for (var cell in fileCells) {
      final cellType = cell["cell_type"] as String?;
      final source = cell["source"] as List?;
      if (cellType == "code" && source != null) {
        lineCount += source.length;
      }
    }
    final fileName = p.basename(filePath);
    setState(() {
      _notebooks.add(JupyterNotebookInfo(fileName, filePath, lineCount));
      _sumLineCount += lineCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ListView(children: [
          DataTable(columns: const [
            DataColumn(
                label: Expanded(
                    child: Text("文件名",
                        style: TextStyle(fontWeight: FontWeight.bold)))),
            DataColumn(
                label: Expanded(
                    child: Text("路径",
                        style: TextStyle(fontWeight: FontWeight.bold)))),
            DataColumn(
                label: Expanded(
                    child: Text("行数",
                        style: TextStyle(fontWeight: FontWeight.bold))))
          ], rows: getNotebookRows)
        ]),
      ),
      appBar: AppBar(
          title: const Text("Jupyter代码统计"),
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.15)),
      floatingActionButton:
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Text(
          "总计: $_sumLineCount 行",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 24),
        FloatingActionButton(
            onPressed: () async {
              FilePickerResult? result = await FilePicker.platform.pickFiles(
                  type: FileType.custom, allowedExtensions: ['ipynb']);
              if (result != null) {
                try {
                  readJupyterNotebook(result.files.single.path!);
                } on FormatException {
                  return;
                }
              }
            },
            child: const Icon(Icons.file_open)),
        const SizedBox(width: 24),
        FloatingActionButton(
            onPressed: () async {
              String? selectedDirectory =
                  await FilePicker.platform.getDirectoryPath();
              if (selectedDirectory != null) {
                final jupyterNotebooks = Glob("*.ipynb");
                await for (var entity
                    in jupyterNotebooks.list(root: selectedDirectory)) {
                  readJupyterNotebook(entity.path);
                }
              }
            },
            child: const Icon(Icons.folder_open))
      ]),
    );
  }

  List<DataRow> get getNotebookRows => _notebooks
      .map((e) => DataRow(cells: [
            DataCell(Text(e.fileName)),
            DataCell(Text(e.filePath)),
            DataCell(Text(e.lineCount.toString())),
          ]))
      .toList();
}
