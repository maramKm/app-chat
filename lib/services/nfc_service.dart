import 'package:nfc_manager/nfc_manager.dart';

class NFCService {
  static Future<void> startNFC(Function(String) onUserDetected) async {
    bool isAvailable = await NfcManager.instance.isAvailable();

    if (!isAvailable) {
      return Future.value();  
    }

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        try {
          final ndef = Ndef.from(tag);
          if (ndef == null) {
            return Future.value();  
          }

          final message = ndef.cachedMessage;
          if (message == null) {
            return Future.value();  
          }

          if (message.records.isEmpty) {
            return Future.value();  
          }

          final record = message.records.first;
          final payload = record.payload;

          // NDEF text format : skip first 3 bytes (encoding metadata)
          final userId = String.fromCharCodes(payload).substring(3);

          onUserDetected(userId);
        } catch (e) {
          print("NFC read error: $e");
          return Future.value();    
        }
      },
    );
  }

  
}
