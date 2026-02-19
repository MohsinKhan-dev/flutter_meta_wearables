package com.meta.wearable.flutter

import io.flutter.plugin.common.EventChannel

class WearablesStreamHandlers {

    class RegistrationStateHandler : EventChannel.StreamHandler {
        var eventSink: EventChannel.EventSink? = null
            private set

        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            eventSink = events
        }

        override fun onCancel(arguments: Any?) {
            eventSink = null
        }
    }

    class DevicesHandler : EventChannel.StreamHandler {
        var eventSink: EventChannel.EventSink? = null
            private set

        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            eventSink = events
        }

        override fun onCancel(arguments: Any?) {
            eventSink = null
        }
    }

    class StreamStateHandler : EventChannel.StreamHandler {
        var eventSink: EventChannel.EventSink? = null
            private set

        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            eventSink = events
        }

        override fun onCancel(arguments: Any?) {
            eventSink = null
        }
    }

    class VideoFrameInfoHandler : EventChannel.StreamHandler {
        var eventSink: EventChannel.EventSink? = null
            private set

        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            eventSink = events
        }

        override fun onCancel(arguments: Any?) {
            eventSink = null
        }
    }

    class StreamErrorsHandler : EventChannel.StreamHandler {
        var eventSink: EventChannel.EventSink? = null
            private set

        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            eventSink = events
        }

        override fun onCancel(arguments: Any?) {
            eventSink = null
        }
    }
}
