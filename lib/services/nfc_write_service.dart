import 'package:nfc_manager/nfc_manager.dart';

class NFCWriteService {
  static Future<void> writeUserId(String userId) async {
    final message = NdefMessage([
      NdefRecord.createText(userId),
    ]);

    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      print("NFC not available");
      return;
    }

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        try {
          final ndef = Ndef.from(tag);

          if (ndef == null) {
            NfcManager.instance.stopSession(
              errorMessage: "Tag is not NDEF compatible",
            );
            return;
          }

          if (!ndef.isWritable) {
            NfcManager.instance.stopSession(
              errorMessage: "Tag is not writable",
            );
            return;
          }

          await ndef.write(message);

          NfcManager.instance.stopSession();
          print("User ID written successfully!");
        } catch (e) {
          NfcManager.instance.stopSession(
            errorMessage: "Error writing tag: $e",
          );
        }
      },

      onError: (error) async {
        print("NFC Error: $error");
        return; 
      },
    );

    return;
  }
}
