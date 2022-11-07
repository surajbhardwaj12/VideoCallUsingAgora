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
class ViewController: UIViewController {
    
    //MARK: - Outlet
    @IBOutlet weak var interfaceStack: UIStackView!
    @IBOutlet weak var shareView: UIView!
    @IBOutlet weak var screenShareView: UIView!
    @IBOutlet weak var btnSpeaker: UIButton!
    @IBOutlet weak var btnMic: UIButton!
    @IBOutlet weak var btnCall: UIButton!
    @IBOutlet weak var btnCamera: UIButton!
    @IBOutlet weak var RemoteView: UIView!
    @IBOutlet weak var LocalView: UIView!
    @IBOutlet weak var muteSwitch: UISwitch!
    @IBOutlet weak var imgMuteMic: UIImageView!
    @IBOutlet weak var imgMuteVideo: UIImageView!
    @IBOutlet weak var volumeSlider: UISlider!
    
    
    //MARK: - Variable
    var localVideo: AgoraRtcVideoCanvas?
    var remoteVideo: AgoraRtcVideoCanvas?
    var frontCameraDeviceInput: AVCaptureDeviceInput?
    var backCameraDeviceInput: AVCaptureDeviceInput?
    // The main entry point for Video SDK
    var agoraEngine: AgoraRtcEngineKit!
    // By default, set the current user role to broadcaster to both send and receive streams.
    var userRole: AgoraClientRole = .broadcaster
    // Update with the App ID of your project generated on Agora Console.
    let appID = "f78ae08b866747b0856400d46bbfc9eb"
    // Update with the temporary token generated in Agora Console.
    var token = "007eJxTYNBaz/Cu4u/jLUyrzj00Xy0i+1MjPFPsw9qd99szNDyfX6xTYEgzt0hMNbBIsjAzMzcxTzKwMDUzMTBIMTFLSkpLtkxN8pqWkdwQyMiw4dkkJkYGCATxWRhy8vMLGBgAwYYhTg=="
    // Update with the channel name you used to generate the token in Agora Console.
    var channelName = "loop"
    // The video feed for the local user is displayed here
    var joined: Bool = false
    //    var speaker: Bool = true
    // Volume Control
    var volume: Int = 50
    var isMuted: Bool = false
    var remoteUid: UInt = 0 // Stores the uid of the remote user
    // Screen sharing
    let screenShareExtensionName = "screenSharer"
    private var initialCenter: CGPoint = .zero
    
    
    //MARK: - LifeCycle
    override func viewDidLoad() {
        super.viewDidLoad()
        // Initializes the video view
        initViews()
        // The following functions are used when calling Agora APIs
        initializeAgoraEngine()
//        setupVideo()
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(didPan(_:)))
        LocalView.addGestureRecognizer(panGestureRecognizer)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        leaveChannel()
        DispatchQueue.global(qos: .userInitiated).async {AgoraRtcEngineKit.destroy()}
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        print("viewDid")
    }
    
    //MARK: - CustomMethod
    func joinChannel() {
        if !self.checkForPermissions() {
            showMessage(title: "Error", text: "Permissions were not granted")
            return
        }
        let option = AgoraRtcChannelMediaOptions()
        
        // Set the client role option as broadcaster or audience.
        if self.userRole == .broadcaster {
            option.clientRoleType = .broadcaster
            setupLocalVideo()
        } else {
            option.clientRoleType = .audience
        }
        // For a video call scenario, set the channel profile as communication.
        option.channelProfile = .communication
        
        // Join the channel with a temp token. Pass in your token and channel name here
        let result = agoraEngine.joinChannel(
            byToken: token, channelId: channelName, uid: 0, mediaOptions: option,
            joinSuccess: { (channel, uid, elapsed) in }
        )
        // Check if joining the channel was successful and set joined Bool accordingly
        if (result == 0) {
            joined = true
            showMessage(title: "Success", text: "Successfully joined the channel as \(self.userRole)")
            print(self.userRole)
        }
    }
    
    func leaveChannel() {
        agoraEngine.stopPreview()
        let result = agoraEngine.leaveChannel(nil)
//
        // Check if leaving the channel was successful and set joined Bool accordingly
        if (result == 0) { joined = false }
    }
    func resetUIView(){
        btnMic.setImage(UIImage(named: "mic"), for: .normal)
        btnSpeaker.setImage(UIImage(named: "video"), for: .normal)
        imgMuteMic.isHidden = true
        imgMuteVideo.isHidden = true
        
        agoraEngine.muteLocalVideoStream(false)
        agoraEngine.muteLocalAudioStream(false)
        
        
    }
    func initializeAgoraEngine() {
        let config = AgoraRtcEngineConfig()
        // Pass in your App ID here.
        config.appId = appID
        // Use AgoraRtcEngineDelegate for the following delegate parameter.
        agoraEngine = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        //        agoraEngine.setDefaultAudioRouteToSpeakerphone(speaker)
        
    }
    
    func initViews() {
        interfaceStack.heightAnchor.constraint(equalTo: btnCall.widthAnchor).isActive = true
        if !joined{
            btnMic.isHidden = true
            btnCamera.isHidden = true
            btnSpeaker.isHidden = true
            screenShareView.isHidden = true
            imgMuteMic.isHidden = true
            imgMuteVideo.isHidden = true
        }
        volumeSlider.maximumValue = 100
        volumeSlider.value = 80
        volumeSlider.addTarget(self, action: #selector(volumeSliderValueChanged), for: .valueChanged)
        muteSwitch.addTarget(self, action: #selector(muteSwitchValueChanged), for: .touchUpInside)
        prepareScreenSharing()
        
    }
    
    func setupVideo() {
            // In simple use cases, we only need to enable video capturing
            // and rendering once at the initialization step.
            // Note: audio recording and playing is enabled by default.
            
            
            // Set video configuration
            // Please go to this page for detailed explanation
            // https://docs.agora.io/cn/Voice/API%20Reference/java/classio_1_1agora_1_1rtc_1_1_rtc_engine.html#af5f4de754e2c1f493096641c5c5c1d8f
            agoraEngine.setVideoEncoderConfiguration(AgoraVideoEncoderConfiguration(size: AgoraVideoDimension640x360,
                                                                                 frameRate: .fps15,
                                                                                 bitrate: AgoraVideoBitrateStandard,
                                                                                 orientationMode: .adaptative, mirrorMode: .disabled))
        }
    func setupLocalVideo() {
//        // Enable the video module
        agoraEngine.enableVideo()
//        // Start the local video preview
//        agoraEngine.startPreview()
        
        //        localVideo!.uid = 0
        //        localVideo!.renderMode = .hidden
        //        localVideo!.view = LocalView
        //        //        if(localVideo!.view == LocmirrorModealView){
        //        //            localVideo!.view = RemoteView
        //        //        }else if(localVideo!.view == RemoteView){
        //        //        localVideo!.view =  LocalView
        //        //        }else{
        //        //            localVideo!.view = LocalView
        //        //        }
        //        // Set the local video view
        //        agoraEngine.setupLocalVideo(localVideo!)
        let view = UIView(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: LocalView.frame.size))
        localVideo = AgoraRtcVideoCanvas()
        localVideo!.view = view
        localVideo!.renderMode = .hidden
        localVideo!.uid = 0
        LocalView.addSubview(localVideo!.view!)
        agoraEngine.setupLocalVideo(localVideo)
        agoraEngine.startPreview()
    }
    
    @objc func buttonAction(sender: UIButton!) {
        if !joined {
            joinChannel()
            // Check if successfully joined the channel and set button title accordingly
            if joined { btnCall.setImage(UIImage(named: "end"), for: .normal) }
        } else {
            leaveChannel()
            // Check if successfully left the channel and set button title accordingly
            if !joined { btnCall.setImage(UIImage(named: "call"), for: .normal) }
        }
    }
    func checkForPermissions() -> Bool {
        var hasPermissions = false
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: hasPermissions = true
        default: hasPermissions = requestCameraAccess()
        }
        // Break out, because camera permissions have been denied or restricted.
        if !hasPermissions { return false }
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: hasPermissions = true
        default: hasPermissions = requestAudioAccess()
        }
        return hasPermissions
    }
    func showMessage(title: String, text: String, delay: Int = 2) -> Void {
        let alert = UIAlertController(title: title, message: text, preferredStyle: .alert)
        self.present(alert, animated: true)
        let deadlineTime = DispatchTime.now() + .seconds(delay)
        DispatchQueue.main.asyncAfter(deadline: deadlineTime, execute: {
            alert.dismiss(animated: true, completion: nil)
        })
    }
    
    func requestCameraAccess() -> Bool {
        var hasCameraPermission = false
        let semaphore = DispatchSemaphore(value: 0)
        AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
            hasCameraPermission = granted
            semaphore.signal()
        })
        semaphore.wait()
        return hasCameraPermission
    }
    
    func requestAudioAccess() -> Bool {
        var hasAudioPermission = false
        let semaphore = DispatchSemaphore(value: 0)
        AVCaptureDevice.requestAccess(for: .audio, completionHandler: { granted in
            hasAudioPermission = granted
            semaphore.signal()
        })
        semaphore.wait()
        return hasAudioPermission
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
        if parent == LocalView {
            canvas!.view!.frame.size = RemoteView.frame.size
            RemoteView.addSubview(canvas!.view!)
        } else if parent == RemoteView {
            canvas!.view!.frame.size = LocalView.frame.size
            LocalView.addSubview(canvas!.view!)
        }
    }
    //MARK: - Action Method
    @IBAction func btnMicClick(_ sender: UIButton) {
        sender.isSelected.toggle()
        if sender.isSelected{
            btnMic.setImage(UIImage(named: "mute"), for: .normal)
            agoraEngine.muteLocalAudioStream(true)
            imgMuteMic.isHidden = false
            
        }else{
            btnMic.setImage(UIImage(named: "mic"), for: .normal)
            agoraEngine.muteLocalAudioStream(false)
            imgMuteMic.isHidden = true
        }
        
    }
    @IBAction func switchView(_ sender: Any) {
        switchView(localVideo)
        switchView(remoteVideo)
        
    }
    @IBAction func btnCameraClick(_ sender: UIButton) {
        sender.isSelected.toggle()
        agoraEngine.switchCamera()
    }
    @IBAction func btnVideoClick(_ sender: UIButton) {
        sender.isSelected.toggle()
        if sender.isSelected {
            btnSpeaker.setImage(UIImage(named: "muteVideo"), for: .normal)
            //           agoraEngine.muteRemoteVideoStream(remoteUid, mute: true)
            agoraEngine.muteLocalVideoStream(true)
            agoraEngine.stopPreview()
            imgMuteVideo.isHidden = false
            
        }else{
            btnSpeaker.setImage(UIImage(named: "video"), for: .normal)
            //           agoraEngine.muteRemoteVideoStream(remoteUid, mute: false)
            agoraEngine.muteLocalVideoStream(false)
            agoraEngine.startPreview()
            imgMuteVideo.isHidden = true
            
            
        }
    }
    @IBAction func btnCallClick(_ sender: Any) {
        if !joined {
            joinChannel()
            // Check if successfully joined the channel and set button title accordingly
            if joined { btnCall.setImage(UIImage(named: "end"), for: .normal)
                btnMic.isHidden = false
                btnCamera.isHidden = false
                btnSpeaker.isHidden = false
                screenShareView.isHidden = false
            }
        } else {
            leaveChannel()
            removeFromParent(localVideo)
            localVideo = nil
            removeFromParent(remoteVideo)
            remoteVideo = nil
            // Check if successfully left the channel and set button title accordingly
            if !joined { btnCall.setImage(UIImage(named: "call"), for: .normal)
                btnMic.isHidden = true
                btnCamera.isHidden = true
                btnSpeaker.isHidden = true
                screenShareView.isHidden = true
            }
        }
        
    }
}
extension ViewController: AgoraRtcEngineDelegate {
    // Callback called when a new host joins the channel
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
//
//        remoteUid = uid
//        remoteVideo!.uid = uid
//        remoteVideo!.renderMode = .hidden
//        remoteVideo!.view = RemoteView
//        agoraEngine.setupRemoteVideo(remoteVideo!)
        var parent: UIView = RemoteView
                if let it = localVideo, let view = it.view {
                    if view.superview == parent {
                        parent = LocalView
                    }
                }
        if remoteVideo != nil {
                    return
                }
                let view = UIView(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: parent.frame.size))
                remoteVideo = AgoraRtcVideoCanvas()
                remoteVideo!.view = view
                remoteVideo!.renderMode = .hidden
                remoteVideo!.uid = uid
                parent.addSubview(remoteVideo!.view!)
                agoraEngine.setupRemoteVideo(remoteVideo!)
        
    }
    @objc func volumeSliderValueChanged(_ sender: UISlider) {
        volume = Int(sender.value)
        print("Changing volume to \(volume)")
        agoraEngine.adjustRecordingSignalVolume(volume)
    }
    
    @objc func muteSwitchValueChanged(_ sender: UISwitch) {
        isMuted = sender.isOn
        print("Changing mute state to \(isMuted)")
        agoraEngine.muteRemoteAudioStream(remoteUid, mute: isMuted)
    }
    
}


