import FlutterMacOS

/// Helper for sending messages to Flutter via method channel
class FlutterMessageSender {
    private let channel: FlutterMethodChannel

    init(channel: FlutterMethodChannel) {
        self.channel = channel
    }

    func sendStatus(_ status: String) {
        DispatchQueue.main.async {
            self.channel.invokeMethod("onStatusChanged", arguments: status)
        }
    }

    func sendTextCaptured(_ text: String) {
        DispatchQueue.main.async {
            self.channel.invokeMethod("onTextCaptured", arguments: text)
        }
    }

    func sendVariantsGenerated(_ content: String) {
        DispatchQueue.main.async {
            self.channel.invokeMethod("onVariantsGenerated", arguments: content)
        }
    }

    func sendStoreContext(text: String, replace: Bool) {
        let args: [String: Any] = ["text": text, "replace": replace]
        DispatchQueue.main.async {
            self.channel.invokeMethod("storeContext", arguments: args)
        }
    }

    func sendSuccess() {
        DispatchQueue.main.async {
            self.channel.invokeMethod("onSuccess", arguments: nil)
        }
    }

    func sendError(_ error: String) {
        DispatchQueue.main.async {
            self.channel.invokeMethod("onError", arguments: error)
        }
    }

    func sendProviderAuthFailure(provider: String, message: String) {
        let args: [String: Any] = ["provider": provider, "message": message]
        DispatchQueue.main.async {
            self.channel.invokeMethod("onProviderAuthFailure", arguments: args)
        }
    }

    func sendNotEditable(_ reason: String) {
        DispatchQueue.main.async {
            self.channel.invokeMethod("onNotEditable", arguments: reason)
        }
    }

    func sendOpenSettings() {
        #if DEBUG
        print("🔵 FlutterMessageSender: sendOpenSettings() called")
        #endif
        DispatchQueue.main.async {
            #if DEBUG
            print("🔵 FlutterMessageSender: invoking 'openSettings' on channel")
            #endif
            self.channel.invokeMethod("openSettings", arguments: nil)
            #if DEBUG
            print("🔵 FlutterMessageSender: 'openSettings' invoked")
            #endif
        }
    }

    func sendTimingData(model: String, seconds: Double) {
        #if DEBUG
        print("FlutterMessageSender: sendTimingData - model: \(model), seconds: \(seconds)")
        #endif
        let args: [String: Any] = ["model": model, "seconds": seconds]
        DispatchQueue.main.async {
            self.channel.invokeMethod("onTimingData", arguments: args)
        }
    }
}
