//
//  ViewController.swift
//  VideoCallWithAgora
//
//  Created by IPS-161 on 31/10/22.
//

import UIKit
import AVFoundation
import AgoraRtcKit
import ReplayKit
import ARKit
class ViewController: UIViewController {
    
    //MARK: - Outlet
    @IBOutlet weak var remoteVideoMutedIndicator: UIImageView!
    @IBOutlet weak var interfaceStack: UIStackView!
    @IBOutlet weak var shareView: UIView!
    @IBOutlet weak var screenShareView: UIView!
    @IBOutlet weak var btnVideo: UIButton!
    @IBOutlet weak var btnMic: UIButton!
    @IBOutlet weak var btnCall: UIButton!
    @IBOutlet weak var btnCamera: UIButton!
    @IBOutlet weak var remoteContainer: UIView!
    @IBOutlet weak var localContainer: UIView!
    @IBOutlet weak var localVideoMutedIndicator: UIImageView!
    @IBOutlet weak var imgMuteVideo: UIImageView!
   
    
    
    //MARK: - Variable
//    weak var logVC: LogViewController?
    var agoraKit: AgoraRtcEngineKit!
    var localVideo: AgoraRtcVideoCanvas?
    var remoteVideo: AgoraRtcVideoCanvas?
    
    var isRemoteVideoRender: Bool = true {
        didSet {
            if let it = localVideo, let view = it.view {
                if view.superview == localContainer {
//                    remoteVideoMutedIndicator.isHidden = isRemoteVideoRender
                    remoteContainer.isHidden = !isRemoteVideoRender
                } else if view.superview == remoteContainer {
                    localVideoMutedIndicator.isHidden = isRemoteVideoRender
                }
            }
        }
    }
    
    var isLocalVideoRender: Bool = false {
        didSet {
            if let it = localVideo, let view = it.view {
                if view.superview == localContainer {
                    localVideoMutedIndicator.isHidden = isLocalVideoRender
                } else if view.superview == remoteContainer {
                    remoteVideoMutedIndicator.isHidden = isLocalVideoRender
                }
            }
        }
    }
    
    var isStartCalling: Bool = true {
        didSet {
            if isStartCalling {
                btnMic.isSelected = false
            }
            btnMic.isHidden = !isStartCalling
            btnCamera.isHidden = !isStartCalling
            btnVideo.isHidden = !isStartCalling
            screenShareView.isHidden = !isStartCalling
        
        }
    }
    // Screen sharing
    let screenShareExtensionName = "screenSharer"
    private var initialCenter: CGPoint = .zero
    
    
    //MARK: - LifeCycle
    override func viewDidLoad() {
        super.viewDidLoad()
        isStartCalling = false
        interfaceStack.heightAnchor.constraint(equalTo: btnCall.widthAnchor).isActive = true
        
        initializeAgoraEngine()
        setupVideo()
        setupLocalVideo()
//        joinChannel()
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(didPan(_:)))
        localContainer.addGestureRecognizer(panGestureRecognizer)
    }
    
    
    //MARK: - CustomMethod
    
    func initializeAgoraEngine() {
        
        // init AgoraRtcEngineKit
        agoraKit = AgoraRtcEngineKit.sharedEngine(withAppId: AppID, delegate: self)
    }
    func setupVideo() {
        // In simple use cases, we only need to enable video capturing
        // and rendering once at the initialization step.
        // Note: audio recording and playing is enabled by default.
        agoraKit.enableVideo()
        
        // Set video configuration
        // Please go to this page for detailed explanation
        // https://docs.agora.io/cn/Voice/API%20Reference/java/classio_1_1agora_1_1rtc_1_1_rtc_engine.html#af5f4de754e2c1f493096641c5c5c1d8f
        agoraKit.setVideoEncoderConfiguration(AgoraVideoEncoderConfiguration(size: AgoraVideoDimension640x360,
                                                                             frameRate: .fps15,
                                                                             bitrate: AgoraVideoBitrateStandard,
                                                                             orientationMode: .adaptative, mirrorMode: .disabled))
    }
    func setupLocalVideo() {
        // This is used to set a local preview.
        // The steps setting local and remote view are very similar.
        // But note that if the local user do not have a uid or do
        // not care what the uid is, he can set his uid as ZERO.
        // Our server will assign one and return the uid via the block
        // callback (joinSuccessBlock) after
        // joining the channel successfully.
        let view = UIView(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: localContainer.frame.size))
        localVideo = AgoraRtcVideoCanvas()
        localVideo!.view = view
        localVideo!.renderMode = .hidden
        localVideo!.uid = 0
        localContainer.addSubview(localVideo!.view!)
        agoraKit.setupLocalVideo(localVideo)
        agoraKit.startPreview()
    }
    func joinChannel() {
        // Set audio route to speaker
        agoraKit.setDefaultAudioRouteToSpeakerphone(true)
        agoraKit.joinChannel(byToken: Token, channelId: "talk", info: nil, uid: 0) { [unowned self] (channel, uid, elapsed) -> Void in
            self.isLocalVideoRender = true
            //            self.logVC?.log(type: .info, content: "did join channel")
            print("did join channel")
        }
        prepareScreenSharing()
        isStartCalling = true
        UIApplication.shared.isIdleTimerDisabled = true
    }
    func leaveChannel() {
        // leave channel and end chat
        agoraKit.leaveChannel(nil)
        
        isRemoteVideoRender = false
        isLocalVideoRender = false
        isStartCalling = false
        UIApplication.shared.isIdleTimerDisabled = false
//        self.logVC?.log(type: .info, content: "did leave channel")
        print("did leave channel")
    }
    
    
  
    


    func showMessage(title: String, text: String, delay: Int = 2) -> Void {
        let alert = UIAlertController(title: title, message: text, preferredStyle: .alert)
        self.present(alert, animated: true)
        let deadlineTime = DispatchTime.now() + .seconds(delay)
        DispatchQueue.main.asyncAfter(deadline: deadlineTime, execute: {
            alert.dismiss(animated: true, completion: nil)
        })
    }
    

    

    func prepareScreenSharing() {
        
        let systemBroadcastPicker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        systemBroadcastPicker.showsMicrophoneButton = false
        systemBroadcastPicker.autoresizingMask = [.flexibleTopMargin, .flexibleRightMargin]
        if let url = Bundle.main.url(forResource: screenShareExtensionName, withExtension: "appex", subdirectory: "PlugIns") {
            if let bundle = Bundle(url: url) {
                systemBroadcastPicker.preferredExtension = bundle.bundleIdentifier
            }
        }
        self.screenShareView.addSubview(systemBroadcastPicker)
        systemBroadcastPicker.translatesAutoresizingMaskIntoConstraints = false
        systemBroadcastPicker.leftAnchor.constraint(equalTo: self.screenShareView.leftAnchor).isActive = true
        systemBroadcastPicker.rightAnchor.constraint(equalTo: self.screenShareView.rightAnchor).isActive = true
        systemBroadcastPicker.topAnchor.constraint(equalTo: self.screenShareView.topAnchor).isActive = true
        systemBroadcastPicker.bottomAnchor.constraint(equalTo: self.screenShareView.bottomAnchor).isActive = true
    }
    @objc func didPan(_ sender: UIPanGestureRecognizer) {
        let translation = sender.translation(in: self.view)
        
        let newX = sender.view!.center.x + translation.x
        let newY = sender.view!.center.y + translation.y
        let senderWidth = sender.view!.bounds.width / 2
        let senderHight = sender.view!.bounds.height / 2
        
        if newX <= senderWidth
        {
            sender.view!.center = CGPoint(x: senderWidth, y: sender.view!.center.y + translation.y)
        }
        else if newX >= self.view.bounds.maxX - senderWidth
        {
            sender.view!.center = CGPoint(x: self.view.bounds.maxX - senderWidth, y: sender.view!.center.y + translation.y)
        }
        if newY <= senderHight
        {
            sender.view!.center = CGPoint(x: sender.view!.center.x + translation.x, y: senderHight)
        }
        else if newY >= self.view.bounds.maxY - senderHight
        {
            sender.view!.center = CGPoint(x: sender.view!.center.x + translation.x, y: self.view.bounds.maxY - senderHight)
        }
        else
        {
            sender.view!.center = CGPoint(x: sender.view!.center.x + translation.x, y: sender.view!.center.y + translation.y)
        }
        
        sender.setTranslation(.zero, in: self.view)
    }
    func removeFromParent(_ canvas: AgoraRtcVideoCanvas?) -> UIView? {
        if let it = canvas, let view = it.view {
            let parent = view.superview
            if parent != nil {
                view.removeFromSuperview()
                return parent
            }
        }
        return nil
    }
    func switchView(_ canvas: AgoraRtcVideoCanvas?) {
        let parent = removeFromParent(canvas)
        if parent == localContainer {
            canvas!.view!.frame.size = remoteContainer.frame.size
            remoteContainer.addSubview(canvas!.view!)
        } else if parent == remoteContainer {
            canvas!.view!.frame.size = localContainer.frame.size
            localContainer.addSubview(canvas!.view!)
        }
    }
    //MARK: - Action Method
    @IBAction func btnMicClick(_ sender: UIButton) {
        sender.isSelected.toggle()
        // mute local audio
        agoraKit.muteLocalAudioStream(sender.isSelected)
        
    }
    @IBAction func switchView(_ sender: Any) {
        switchView(localVideo)
        switchView(remoteVideo)
        
    }
    @IBAction func btnCameraClick(_ sender: UIButton) {
        sender.isSelected.toggle()
        agoraKit.switchCamera()
    }
    @IBAction func btnVideoClick(_ sender: UIButton) {
        sender.isSelected.toggle()
        if sender.isSelected {
            btnVideo.setImage(UIImage(named: "muteVideo"), for: .normal)
            //           agoraEngine.muteRemoteVideoStream(remoteUid, mute: true)
            agoraKit.muteLocalVideoStream(true)
            agoraKit.stopPreview()
            imgMuteVideo.isHidden = false
            
        }else{
            btnVideo.setImage(UIImage(named: "video"), for: .normal)
            //           agoraEngine.muteRemoteVideoStream(remoteUid, mute: false)
            agoraKit.muteLocalVideoStream(false)
            agoraKit.startPreview()
            imgMuteVideo.isHidden = true
            
            
        }
    }
    @IBAction func btnCallClick(_ sender: UIButton) {
        sender.isSelected.toggle()
        if sender.isSelected {
            leaveChannel()
            removeFromParent(localVideo)
            localVideo = nil
            removeFromParent(remoteVideo)
            remoteVideo = nil
        } else {
            setupLocalVideo()
            joinChannel()
        }
        
    }
}
extension ViewController: AgoraRtcEngineDelegate {

    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        isRemoteVideoRender = true

        var parent: UIView = remoteContainer
        if let it = localVideo, let view = it.view {
            if view.superview == parent {
                parent = localContainer
            }
        }

        // Only one remote video view is available for this
        // tutorial. Here we check if there exists a surface
        // view tagged as this uid.
        if remoteVideo != nil {
            return
        }

        let view = UIView(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: parent.frame.size))
        remoteVideo = AgoraRtcVideoCanvas()
        remoteVideo!.view = view
        remoteVideo!.renderMode = .hidden
        remoteVideo!.uid = uid
        parent.addSubview(remoteVideo!.view!)
        agoraKit.setupRemoteVideo(remoteVideo!)
    }
    
    /// Occurs when a remote user (Communication)/host (Live Broadcast) leaves a channel.
    /// - Parameters:
    ///   - engine: RTC engine instance
    ///   - uid: ID of the user or host who leaves a channel or goes offline.
    ///   - reason: Reason why the user goes offline
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid:UInt, reason:AgoraUserOfflineReason) {
        isRemoteVideoRender = false
        if let it = remoteVideo, it.uid == uid {
            removeFromParent(it)
            remoteVideo = nil
        }
    }
    
    /// Occurs when a remote user’s video stream playback pauses/resumes.
    /// - Parameters:
    ///   - engine: RTC engine instance
    ///   - muted: YES for paused, NO for resumed.
    ///   - byUid: User ID of the remote user.
    func rtcEngine(_ engine: AgoraRtcEngineKit, didVideoMuted muted:Bool, byUid:UInt) {
        isRemoteVideoRender = !muted
    }
    
    /// Reports a warning during SDK runtime.
    /// - Parameters:
    ///   - engine: RTC engine instance
    ///   - warningCode: Warning code
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurWarning warningCode: AgoraWarningCode) {
//        logVC?.log(type: .warning, content: "did occur warning, code: \(warningCode.rawValue)")
        print(warningCode.rawValue)
    }
    
    /// Reports an error during SDK runtime.
    /// - Parameters:
    ///   - engine: RTC engine instance
    ///   - errorCode: Error code
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
//        logVC?.log(type: .error, content: "did occur error, code: \(errorCode.rawValue)")
        print(errorCode.rawValue)
    }
}


