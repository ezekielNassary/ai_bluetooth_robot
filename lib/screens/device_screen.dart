import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bluetooth_ai_robot/screens/VoiceWidget.dart';
import 'package:bluetooth_ai_robot/screens/scan_screen.dart';
import 'package:bluetooth_ai_robot/utils/constants.dart';
import 'package:bluetooth_ai_robot/utils/snack_bar.dart';
import 'package:bluetooth_ai_robot/widgets/snack_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_speech/flutter_speech.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../widgets/service_tile.dart';
import '../widgets/characteristic_tile.dart';
import '../widgets/descriptor_tile.dart';

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;
  const DeviceScreen({super.key, required this.device});
  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

const languages = const [
  const Language('Swahili', 'sw_KE'),
  const Language('English', 'en_US'),
];

class Language {
  final String name;
  final String code;

  const Language(this.name, this.code);
}

class _DeviceScreenState extends State<DeviceScreen> {
  int? _rssi;
  int? _mtuSize;
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;
  List<BluetoothService> _services = [];
  bool _isDiscoveringServices = false;
  bool _isConnecting = false;
  bool _isDisconnecting = false;

  late StreamSubscription<BluetoothConnectionState>
      _connectionStateSubscription;
  late StreamSubscription<bool> _isConnectingSubscription;
  late StreamSubscription<bool> _isDisconnectingSubscription;
  late StreamSubscription<int> _mtuSubscription;

  late SpeechRecognition _speech;

  bool _speechRecognitionAvailable = false;
  bool _isListening = false;

  String transcription = '';

  //String _currentLocale = 'en_US';
  Language selectedLang = languages.first;
  void activateSpeechRecognizer() {
    print('_MyAppState.activateSpeechRecognizer... ');
    _speech = SpeechRecognition();
    _speech.setAvailabilityHandler(onSpeechAvailability);
    _speech.setRecognitionStartedHandler(onRecognitionStarted);
    _speech.setRecognitionResultHandler(onRecognitionResult);
    _speech.setRecognitionCompleteHandler(onRecognitionComplete);
    _speech.setErrorHandler(errorHandler);
    _speech.activate('fr_FR').then((res) {
      setState(() => _speechRecognitionAvailable = res);
    });
  }

  late final GenerativeModel _model;
  late final ChatSession _chat;
  String? language;
  String? engine;
  double volume = 0.5;
  double pitch = 1.0;
  double rate = 0.5;
  bool isCurrentLanguageInstalled = false;

  String? _newVoiceText;
  int? _inputLength;
  late FlutterTts flutterTts;
  TtsState ttsState = TtsState.stopped;

  bool get isPlaying => ttsState == TtsState.playing;
  bool get isStopped => ttsState == TtsState.stopped;
  bool get isPaused => ttsState == TtsState.paused;
  bool get isContinued => ttsState == TtsState.continued;

  bool get isIOS => !kIsWeb && Platform.isIOS;
  bool get isAndroid => !kIsWeb && Platform.isAndroid;
  bool get isWindows => !kIsWeb && Platform.isWindows;
  bool get isWeb => kIsWeb;

  dynamic initTts() {
    flutterTts = FlutterTts();

    _setAwaitOptions();

    if (isAndroid) {
      _getDefaultEngine();
      _getDefaultVoice();
    }

    flutterTts.setStartHandler(() {
      setState(() {
        print("Playing");
        ttsState = TtsState.playing;
      });
    });

    flutterTts.setCompletionHandler(() {
      setState(() {
        print("Complete");
        ttsState = TtsState.stopped;
      });
    });

    flutterTts.setCancelHandler(() {
      setState(() {
        print("Cancel");
        ttsState = TtsState.stopped;
      });
    });

    flutterTts.setPauseHandler(() {
      setState(() {
        print("Paused");
        ttsState = TtsState.paused;
      });
    });

    flutterTts.setContinueHandler(() {
      setState(() {
        print("Continued");
        ttsState = TtsState.continued;
      });
    });

    flutterTts.setErrorHandler((msg) {
      setState(() {
        print("error: $msg");
        ttsState = TtsState.stopped;
      });
    });
  }

  Future<dynamic> _getLanguages() async => await flutterTts.getLanguages;

  Future<dynamic> _getEngines() async => await flutterTts.getEngines;

  Future<void> _getDefaultEngine() async {
    var engine = await flutterTts.getDefaultEngine;
    if (engine != null) {
      print(engine);
    }
  }

  Future<void> _getDefaultVoice() async {
    var voice = await flutterTts.getDefaultVoice;
    if (voice != null) {
      print(voice);
    }
  }

  Future<void> _speak(String? txt) async {
    await flutterTts.setVolume(volume);
    await flutterTts.setSpeechRate(rate);
    await flutterTts.setPitch(pitch);

    if (txt != null) {
      if (txt!.isNotEmpty) {
        await flutterTts.speak(txt!);
      }
    }
  }

  Future<void> _setAwaitOptions() async {
    await flutterTts.awaitSpeakCompletion(true);
  }

  Future<void> _stop() async {
    var result = await flutterTts.stop();
    if (result == 1) setState(() => ttsState = TtsState.stopped);
  }

  Future<void> _pause() async {
    var result = await flutterTts.pause();
    if (result == 1) setState(() => ttsState = TtsState.paused);
  }

  @override
  void initState() {
    super.initState();
    _connectionStateSubscription =
        widget.device.connectionState.listen((state) async {
      _connectionState = state;
      if (state == BluetoothConnectionState.connected) {
        _services = []; // must rediscover services
      }
      if (state == BluetoothConnectionState.connected && _rssi == null) {
        _rssi = await widget.device.readRssi();
      }
      if (mounted) {
        setState(() {});
      }
    });
    _mtuSubscription = widget.device.mtu.listen((value) {
      _mtuSize = value;
      if (mounted) {
        setState(() {});
      }
    });

    _connectionStateSubscription =
        widget.device.connectionState.listen((state) async {
      _connectionState = state;
      _isConnecting = state == BluetoothConnectionState.connecting;
      _isDisconnecting = state == BluetoothConnectionState.disconnecting;

      if (state == BluetoothConnectionState.connected) {
        await onDiscoverServicesPressed();
      }

      if (mounted) {
        setState(() {});
      }
    });

    _connectionStateSubscription =
        widget.device.connectionState.listen((state) async {
      _connectionState = state;
      _isConnecting = state == BluetoothConnectionState.connecting;
      _isDisconnecting = state == BluetoothConnectionState.disconnecting;

      if (state == BluetoothConnectionState.connected) {
        await onDiscoverServicesPressed();
      }

      if (mounted) {
        setState(() {});
      }
    });
    activateSpeechRecognizer();
    _model = GenerativeModel(
      model: MODEL,
      apiKey: API_KEY,
    );
    _chat = _model.startChat();
    initTts();
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    _mtuSubscription.cancel();
    _isConnectingSubscription.cancel();
    _isDisconnectingSubscription.cancel();
    flutterTts.stop();
    super.dispose();
  }

  List<DropdownMenuItem<String>> getEnginesDropDownMenuItems(
      List<dynamic> engines) {
    var items = <DropdownMenuItem<String>>[];
    for (dynamic type in engines) {
      items.add(DropdownMenuItem(
          value: type as String?, child: Text((type as String))));
    }
    return items;
  }

  void changedEnginesDropDownItem(String? selectedEngine) async {
    await flutterTts.setEngine(selectedEngine!);
    language = null;
    setState(() {
      engine = selectedEngine;
    });
  }

  List<DropdownMenuItem<String>> getLanguageDropDownMenuItems(
      List<dynamic> languages) {
    var items = <DropdownMenuItem<String>>[];
    for (dynamic type in languages) {
      items.add(DropdownMenuItem(
          value: type as String?, child: Text((type as String))));
    }
    return items;
  }

  void changedLanguageDropDownItem(String? selectedType) {
    setState(() {
      language = selectedType;
      flutterTts.setLanguage(language!);
      if (isAndroid) {
        flutterTts
            .isLanguageInstalled(language!)
            .then((value) => isCurrentLanguageInstalled = (value as bool));
      }
    });
  }

  void _onChange(String text) {
    setState(() {
      _newVoiceText = text;
    });
  }

  Widget _engineSection() {
    if (isAndroid) {
      return FutureBuilder<dynamic>(
          future: _getEngines(),
          builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
            if (snapshot.hasData) {
              return _enginesDropDownSection(snapshot.data as List<dynamic>);
            } else if (snapshot.hasError) {
              return Text('Error loading engines...');
            } else {
              return Text('Loading engines...');
            }
          });
    } else {
      return Container(width: 0, height: 0);
    }
  }

  Widget _btnSection() {
    return Container(
      padding: EdgeInsets.only(top: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildButtonColumn(
              Colors.green, Colors.greenAccent, Icons.play_arrow, 'PLAY', () {
            _speak(transcription);
          }),
          _buildButtonColumn(
              Colors.red, Colors.redAccent, Icons.stop, 'STOP', _stop),
          _buildButtonColumn(
              Colors.blue, Colors.blueAccent, Icons.pause, 'PAUSE', _pause),
        ],
      ),
    );
  }

  Column _buildButtonColumn(Color color, Color splashColor, IconData icon,
      String label, Function func) {
    return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
              icon: Icon(icon),
              color: color,
              splashColor: splashColor,
              onPressed: () => func()),
          Container(
              margin: const EdgeInsets.only(top: 8.0),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w400,
                      color: color)))
        ]);
  }

  Widget _futureBuilder() => FutureBuilder<dynamic>(
      future: _getLanguages(),
      builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
        if (snapshot.hasData) {
          return _languageDropDownSection(snapshot.data as List<dynamic>);
        } else if (snapshot.hasError) {
          return Text('Error loading languages...');
        } else
          return Text('Loading Languages...');
      });
  Widget _buildSliders() {
    return Column(
      children: [_volume(), _pitch(), _rate()],
    );
  }

  Widget _volume() {
    return Slider(
        value: volume,
        onChanged: (newVolume) {
          setState(() => volume = newVolume);
        },
        min: 0.0,
        max: 1.0,
        divisions: 10,
        label: "Volume: ${volume.toStringAsFixed(1)}");
  }

  Widget _pitch() {
    return Slider(
      value: pitch,
      onChanged: (newPitch) {
        setState(() => pitch = newPitch);
      },
      min: 0.5,
      max: 2.0,
      divisions: 15,
      label: "Pitch: ${pitch.toStringAsFixed(1)}",
      activeColor: Colors.red,
    );
  }

  Widget _rate() {
    return Slider(
      value: rate,
      onChanged: (newRate) {
        setState(() => rate = newRate);
      },
      min: 0.0,
      max: 1.0,
      divisions: 10,
      label: "Rate: ${rate.toStringAsFixed(1)}",
      activeColor: Colors.green,
    );
  }

  Widget _languageDropDownSection(List<dynamic> languages) => Container(
      decoration: BoxDecoration(color: Colors.grey[400]),
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Expanded(
              child: Text(
                'Language (sw-Ke Swahili)',
                style: GoogleFonts.poppins(fontSize: 12),
              ),
            ),
            DropdownButton(
              dropdownColor: Colors.white,
              style: GoogleFonts.poppins(
                color: Colors.teal,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              icon: Icon(Icons.arrow_drop_down, color: Colors.teal),
              underline: Container(
                height: 2,
                color: Colors.teal,
              ),
              value: language,
              items: getLanguageDropDownMenuItems(languages),
              onChanged: changedLanguageDropDownItem,
            ),
          ]),
          Visibility(
            visible: isAndroid,
            child: Text(
                "${isCurrentLanguageInstalled ? 'Language Installed' : 'Language Not Installed'}"),
          ),
        ],
      ));

  Widget _enginesDropDownSection(List<dynamic> engines) => Container(
        padding: EdgeInsets.only(top: 50.0),
        child: DropdownButton(
          value: engine,
          items: getEnginesDropDownMenuItems(engines),
          onChanged: changedEnginesDropDownItem,
        ),
      );
  bool aiTrained = false;
  bool processing = false;
  Future<void> sendMessageAI(String message) async {
    print(
        '-----------------------Sending Message to Ai--------------------------');
    try {
      setState(() {
        processing = true;
      });
      final response = await _chat.sendMessage(
        Content.text('$message in respective language only'),
      );
      final text = response.text;
      setState(() {
        processing = false;
      });
      if (message != trainModelText) {
        _speak(text);
      } else {
        setState(() {
          aiTrained = true;
        });
      }
    } catch (e) {
      showErrorSnackbar("Connect Error: $e");
    }
  }

  bool get isConnected {
    return _connectionState == BluetoothConnectionState.connected;
  }

  Future onConnectPressed() async {
    try {
      await widget.device.connect();
      Snackbar.show(ABC.c, "Connect: Success", success: true);
    } catch (e, backtrace) {
      if (e is FlutterBluePlusException &&
          e.code == FbpErrorCode.connectionCanceled.index) {
        // ignore connections canceled by the user
      } else {
        Snackbar.show(ABC.c, prettyException("Connect Error:", e),
            success: false);
        print(e);
        print("backtrace: $backtrace");
      }
    }
  }

  Future onCancelPressed() async {
    try {
      await widget.device.disconnect(queue: false);
      Snackbar.show(ABC.c, "Cancel: Success", success: true);
    } catch (e, backtrace) {
      Snackbar.show(ABC.c, prettyException("Cancel Error:", e), success: false);
      print("$e");
      print("backtrace: $backtrace");
    }
  }

  Future onDisconnectPressed() async {
    try {
      await widget.device.disconnect();
      Snackbar.show(ABC.c, "Disconnect: Success", success: true);
    } catch (e, backtrace) {
      Snackbar.show(ABC.c, prettyException("Disconnect Error:", e),
          success: false);
      print("$e backtrace: $backtrace");
    }
  }

  Future onDiscoverServicesPressed() async {
    if (mounted) {
      setState(() {
        _isDiscoveringServices = true;
      });
    }
    try {
      _services = await widget.device.discoverServices();
      Snackbar.show(ABC.c, "Discover Services: Success", success: true);
    } catch (e, backtrace) {
      Snackbar.show(ABC.c, prettyException("Discover Services Error:", e),
          success: false);
      print(e);
      print("backtrace: $backtrace");
    }
    if (mounted) {
      setState(() {
        _isDiscoveringServices = false;
      });
    }
  }

  Future onRequestMtuPressed() async {
    try {
      await widget.device.requestMtu(223, predelay: 0);
      Snackbar.show(ABC.c, "Request Mtu: Success", success: true);
    } catch (e, backtrace) {
      Snackbar.show(ABC.c, prettyException("Change Mtu Error:", e),
          success: false);
      print(e);
      print("backtrace: $backtrace");
    }
  }

  List<Widget> _buildServiceTiles(BuildContext context, BluetoothDevice d) {
    return _services
        .map(
          (s) => ServiceTile(
            service: s,
            characteristicTiles: s.characteristics
                .map((c) => _buildCharacteristicTile(c))
                .toList(),
          ),
        )
        .toList();
  }

  CharacteristicTile _buildCharacteristicTile(BluetoothCharacteristic c) {
    return CharacteristicTile(
      characteristic: c,
      descriptorTiles:
          c.descriptors.map((d) => DescriptorTile(descriptor: d)).toList(),
    );
  }

  Widget buildSpinner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14.0),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: CircularProgressIndicator(
          backgroundColor: Colors.black12,
          color: Colors.black26,
        ),
      ),
    );
  }

  Widget buildRemoteId(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text('${widget.device.remoteId}'),
    );
  }

  Widget buildRssiTile(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        isConnected
            ? const Icon(Icons.bluetooth_connected)
            : const Icon(Icons.bluetooth_disabled),
        Text(((isConnected && _rssi != null) ? '${_rssi!} dBm' : ''),
            style: Theme.of(context).textTheme.bodySmall)
      ],
    );
  }

  Widget buildGetServices(BuildContext context) {
    return IndexedStack(
      index: (_isDiscoveringServices) ? 1 : 0,
      children: <Widget>[
        TextButton(
          onPressed: onDiscoverServicesPressed,
          child: const Text("Get Services"),
        ),
        const IconButton(
          icon: SizedBox(
            width: 18.0,
            height: 18.0,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Colors.grey),
            ),
          ),
          onPressed: null,
        )
      ],
    );
  }

  Widget buildMtuTile(BuildContext context) {
    return ListTile(
        title: const Text('MTU Size'),
        subtitle: Text('$_mtuSize bytes'),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: onRequestMtuPressed,
        ));
  }

  Widget buildConnectButton(BuildContext context) {
    return Row(children: [
      if (_isConnecting || _isDisconnecting) buildSpinner(context),
      ElevatedButton(
          onPressed: _isConnecting
              ? onCancelPressed
              : (isConnected ? onDisconnectPressed : onConnectPressed),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
          child: Text(
            _isConnecting ? "CANCEL" : (isConnected ? "DISCONNECT" : "CONNECT"),
            style: Theme.of(context)
                .primaryTextTheme
                .labelLarge
                ?.copyWith(color: Colors.white),
          ))
    ]);
  }

  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      drawer: Drawer(),
      appBar: AppBar(
        backgroundColor: Colors.teal,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          widget.device.platformName == ''
              ? "AI ROBOT"
              : widget.device.platformName,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            color: Colors.teal,
            child: ListTile(
              leading: buildRssiTile(context),
              title: Text(
                  'Device is ${_connectionState.toString().split('.')[1]}.'),
              trailing: buildGetServices(context),
            ),
          ), // Replace with your desired widget
        ),
        actions: [buildConnectButton(context), const SizedBox(width: 15)],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            // buildRemoteId(context),

            Container(
              width: double.infinity,
              padding: EdgeInsets.all(8),
              child: ElevatedButton(
                  onPressed: () async {
                    await sendMessageAI(trainModelText);
                  },
                  child: Text(
                    processing ? 'Please Wait...' : 'Train Ai',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal),
                  )),
            ),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.green),
              child: Row(
                children: [
                  Expanded(
                    child: _buildButton(
                      onPressed: _speechRecognitionAvailable && !_isListening
                          ? () => start()
                          : null,
                      label: _isListening
                          ? 'Listening...'
                          : 'Listen (${selectedLang.code})',
                    ),
                  ),
                  _buildButton(
                    onPressed: _isListening ? () => cancel() : null,
                    label: 'Cancel',
                  ),
                  _buildButton(
                    onPressed: _isListening ? () => stop() : null,
                    label: 'Stop',
                  ),
                ],
              ),
            ),
            Text(transcription),
            const SizedBox(height: 20),
            // _engineSection(),
            _futureBuilder(),
            _btnSection(),
            _buildSliders(),

            Center(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildDirectionButton("↑", () => _sendCommand("forward")),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildDirectionButton("←", () => _sendCommand("left")),
                      _buildDirectionButton("⏺", () => _sendCommand("stop")),
                      _buildDirectionButton("→", () => _sendCommand("right")),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildDirectionButton(
                          "↓", () => _sendCommand("backward")),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
            buildMtuTile(context),
            // ..._buildServiceTiles(context, widget.device),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          MaterialPageRoute route = MaterialPageRoute(
              builder: (context) => ScanScreen(),
              settings: RouteSettings(name: '/ScanScreen'));
          Navigator.of(context).push(route);
        },
        child: Icon(Icons.list),
      ),
    );
  }

  Widget _buildDirectionButton(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(20),
          backgroundColor: Colors.blue,
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 20, color: Colors.white)),
      ),
    );
  }

//  Future<void> _sendCommand(Map<String, dynamic> data) async {
//     await onRequestMtuPressed();
//     List<BluetoothService> services = await widget.device.discoverServices();
//     services.forEach((service) async {
//       var characteristics = service.characteristics;
//       for (BluetoothCharacteristic c in characteristics) {
//         if (c.properties.write) {
//           List<int> bytes = utf8.encode(jsonEncode(data));
//           await c.write(bytes, allowLongWrite: true);
//         }
//       }
//     });
//   }
  Future<void> _sendCommand(String cmd) async {
    await onRequestMtuPressed();
    List<BluetoothService> services = await widget.device.discoverServices();
    services.forEach((service) async {
      var characteristics = service.characteristics;
      for (BluetoothCharacteristic c in characteristics) {
        if (c.properties.write) {
          List<int> bytes = utf8.encode(cmd);
          await c.write(bytes, allowLongWrite: true);
        }
      }
    });
  }

  Future<void> _startListening() async {
    print("Listening.........");
  }

  List<CheckedPopupMenuItem<Language>> get _buildLanguagesWidgets => languages
      .map((l) => CheckedPopupMenuItem<Language>(
            value: l,
            checked: selectedLang == l,
            child: Text(l.name),
          ))
      .toList();

  void _selectLangHandler(Language lang) {
    setState(() => selectedLang = lang);
  }

  Widget _buildButton({required String label, VoidCallback? onPressed}) =>
      ElevatedButton(
        onPressed: onPressed,
        child: Text(
          label,
          style: GoogleFonts.poppins(color: Colors.green, fontSize: 12),
        ),
      );

  void start() => _speech.activate(selectedLang.code).then((_) {
        return _speech.listen().then((result) {
          print('_MyAppState.start => result $result');
          setState(() {
            _isListening = result;
          });
        });
      });

  void cancel() =>
      _speech.cancel().then((_) => setState(() => _isListening = false));

  void stop() => _speech.stop().then((_) {
        setState(() => _isListening = false);
      });

  void onSpeechAvailability(bool result) =>
      setState(() => _speechRecognitionAvailable = result);

  void onCurrentLocale(String locale) {
    print('_MyAppState.onCurrentLocale... $locale');
    setState(
        () => selectedLang = languages.firstWhere((l) => l.code == locale));
  }

  void onRecognitionStarted() {
    setState(() => _isListening = true);
  }

  void onRecognitionResult(String text) {
    print('_MyAppState.onRecognitionResult... $text');
    setState(() => transcription = text);
  }

  String prevTranscpt = '';
  void onRecognitionComplete(String text) {
    print('_MyAppState.onRecognitionComplete... $text');
    if (!_isListening && transcription != prevTranscpt) {
      prevTranscpt = transcription;
      if (transcription.isNotEmpty && aiTrained) {
        sendMessageAI(transcription);
        setState(() => transcription = '');
      }
    }
    Future.delayed(Duration(
      milliseconds: 100,
    ));
    setState(() => _isListening = false);
  }

  void errorHandler() => activateSpeechRecognizer();
}
