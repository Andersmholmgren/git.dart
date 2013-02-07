// TODO(adam): document methods and class
// TODO(adam): use verbose
// TODO: add an async version that takes Func<Future<Iterable<String>>>
//       see getCompileDocsFunc

part of hop_tasks;

Task createDartAnalyzerTask(Iterable<String> files) {
  return new Task.async((context) {

    final parser = _getDartAnalyzerParser();
    final parseResult = _helpfulParseArgs(context, parser, context.arguments);

    final bool enableTypeChecks = parseResult['enable_type_checks'];
    final bool verbose = parseResult['verbose'];

    final fileList = files.mappedBy((f) => new Path(f)).toList();

    return _processAnalyzerFile(context, fileList, enableTypeChecks, verbose);
  }, 'Running dart analyzer');
}

ArgParser _getDartAnalyzerParser() {
  return new ArgParser()
    ..addFlag('enable_type_checks', help: 'Generate runtime type checks', defaultsTo: false)
    ..addFlag('verbose', help: 'verbose output of all errors', defaultsTo: false);
}

Future<bool> _processAnalyzerFile(TaskContext context, List<Path> analyzerFilePaths,
    bool enableTypeChecks, bool verbose) {

  int errorsCount = 0;
  int passedCount = 0;
  int warningCount = 0;

  return Future.forEach(analyzerFilePaths, (Path path) {
    final logger = context.getSubLogger(path.toString());
    return _analyzer(logger, path, enableTypeChecks, verbose)
        .then((int exitCode) {

          String prefix;

          switch(exitCode) {
            case 0:
              prefix = "PASSED";
              passedCount++;
              break;
            case 1:
              prefix = "WARNING";
              warningCount++;
              break;
            case 2:
              prefix =  "ERROR";
              errorsCount++;
              break;
            default:
              prefix = "Unknown exit code $exitCode";
              errorsCount++;
              break;
          }

          context.info("$prefix - $path");
        });
    })
    .then((_) {
      context.info("PASSED: ${passedCount}, WARNING: ${warningCount}, ERROR: ${errorsCount}");
      return errorsCount == 0;
    });
}

Future<int> _analyzer(TaskLogger logger, Path filePath, bool enableTypeChecks,
    bool verbose) {
  TempDir tmpDir;

  return TempDir.create()
      .then((TempDir td) {
        tmpDir = td;

        var processArgs = ['--extended-exit-code', '--work', tmpDir.dir.path];

        if (enableTypeChecks) {
          processArgs.add('--enable_type_checks');
        }

        processArgs.addAll([filePath.toNativePath()]);

        return Process.start('dart_analyzer', processArgs);
      })
      .then((process) {
        if(verbose) {
          return pipeProcess(process,
              stdOutWriter: logger.fine,
              stdErrWriter: logger.severe);
        } else {
          return pipeProcess(process);
        }
      })
      .whenComplete(() {
        if(tmpDir != null) {
          tmpDir.dispose();
        }
      });
}