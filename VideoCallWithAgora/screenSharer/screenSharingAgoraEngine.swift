//
//  screenSharingAgoraEngine.swift
//  screenSharer
//
//  Created by IPS-161 on 01/11/22.
//

import Foundation
import CoreMedia
import ReplayKit
import AgoraRtcKit

class screenSharingAgoraEngine {

    // Update with the App ID of your project generated on Agora Console.
    private static let appID = "f78ae08b866747b0856400d46bbfc9eb"
    // Update with the temporary token generated in Agora Console.
    private static let  token = "007eJxTYJj48rnEetO+lM/BpnNudW1J41n4W3mpx6LPX8U1b0w/uqNIgSHN3CIx1cAiycLMzNzEPMnAwtTMxMAgxcQsKSkt2TI1aeHSlOSGQEaGXjNtJkYGCATxWRhy8vMLGBgA8BAhNw=="
    // Update with the channel name you used to generate the token in Agora Console.
    private static let  channelName = "talk"
    // Return an instance of Agora Engine that is configured for screen sharing
    private static let agoraEngine: AgoraRtcEngineKit = {

        let config = AgoraRtcEngineConfig()
        config.appId = appID
        config.channelProfile = .liveBroadcasting
        let agoraEngine = AgoraRtcEngineKit.sharedEngine(with: config, delegate: nil)

        agoraEngine.enableVideo()
        agoraEngine.setExternalVideoSource(true, useTexture: true, sourceType: .videoFrame)
        let videoConfig = AgoraVideoEncoderConfiguration(size: videoDimension,
                                                         frameRate: .fps10,
                                                         bitrate: AgoraVideoBitrateStandard,
                                                         orientationMode: .adaptative, mirrorMode: .auto)
        agoraEngine.setVideoEncoderConfiguration(videoConfig)

        agoraEngine.setAudioProfile(.default)
        agoraEngine.setExternalAudioSource(true, sampleRate: Int(audioSampleRate), channels: Int(audioChannels))
        agoraEngine.muteAllRemoteVideoStreams(true)
        agoraEngine.muteAllRemoteAudioStreams(true)
        return agoraEngine
    }()


    // Set the audio configuration
    private static let audioSampleRate: UInt = 44100
    private static let audioChannels: UInt = 2


    // Get the screen size and orientation
    private static let videoDimension: CGSize = {
        let screenSize = UIScreen.main.currentMode!.size
        var boundingSize = CGSize(width: 540, height: 980)
        let mW = boundingSize.width / screenSize.width
        let mH = boundingSize.height / screenSize.height
        if mH < mW {
            boundingSize.width = boundingSize.height / screenSize.height * screenSize.width
        } else if mW < mH {
            boundingSize.height = boundingSize.width / screenSize.width * screenSize.height
        }
        return boundingSize
    }()


    //Configure agoraEngine to use custom video with no audio, then join the channel.
    static func startScreenSharing(to channel: String) {

        let channelMediaOptions = AgoraRtcChannelMediaOptions()
        channelMediaOptions.publishMicrophoneTrack = false
        channelMediaOptions.publishCameraTrack = false
        channelMediaOptions.publishCustomVideoTrack = true
        channelMediaOptions.publishCustomAudioTrack = true
        channelMediaOptions.autoSubscribeAudio = false
        channelMediaOptions.autoSubscribeVideo = false
        channelMediaOptions.clientRoleType = .broadcaster

        agoraEngine.joinChannel(byToken: token, channelId: channelName, uid: UInt(1001), mediaOptions: channelMediaOptions, joinSuccess: nil)
    }


    // Leave the channel
    static func stopScreenSharing() {
        agoraEngine.leaveChannel(nil)
        AgoraRtcEngineKit.destroy()
    }


    //Retrieve the local video frame, figure out the orientation and duration of the buffer and send it to the chnanel.
    static func sendVideoBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let videoFrame = CMSampleBufferGetImageBuffer(sampleBuffer)
        else {
        return
        }

        var rotation: Int32 = 0
        if let orientationAttachment = CMGetAttachment(sampleBuffer, key: RPVideoSampleOrientationKey as CFString, attachmentModeOut: nil) as? NSNumber {
            if let orientation = CGImagePropertyOrientation(rawValue: orientationAttachment.uint32Value) {
                switch orientation {
                case .up,    .upMirrored:    rotation = 0
                case .down,  .downMirrored:  rotation = 180
                case .left,  .leftMirrored:  rotation = 90
                case .right, .rightMirrored: rotation = 270
                default:   break
                }
            }
        }
        let time = CMTime(seconds: CACurrentMediaTime(), preferredTimescale: 1000 * 1000)

        let frame = AgoraVideoFrame()
        frame.format = 12
        frame.time = time
        frame.textureBuf = videoFrame
        frame.rotation = rotation
        agoraEngine.pushExternalVideoFrame(frame)
    }

    // To extend the functionality
    static func sendAudioAppBuffer(_ sampleBuffer: CMSampleBuffer) {

    }

    // Audio is blocked, do nothing
    static func sendAudioMicBuffer(_ sampleBuffer: CMSampleBuffer) {

    }

}

