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
class VideoCallVC: UIViewController {
    //MARK: - Outlet
    @IBOutlet weak var lblLocalVideoPaused: UILabel!
    @IBOutlet weak var lblLocalMicMuted: UILabel!
    @IBOutlet weak var btnRecord: UIButton!
    @IBOutlet weak var interfaceStack: UIStackView!
    @IBOutlet weak var shareView: UIView!
    @IBOutlet weak var screenShareView: UIView!
    @IBOutlet weak var btnVideo: UIButton!
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
    let recorder = RPScreenRecorder.shared()
    private var isRecording = false
    let controller = RPBroadcastController()
    let shareScreenController = SampleHandler()
    var localVideo: AgoraRtcVideoCanvas?
    var remoteVideo: AgoraRtcVideoCanvas?
    var frontCameraDeviceInput: AVCaptureDeviceInput?
    var backCameraDeviceInput: AVCaptureDeviceInput?
    var agoraEngine: AgoraRtcEngineKit!
    var userRole: AgoraClientRole = .broadcaster
    let appID = "f78ae08b866747b0856400d46bbfc9eb"
    var token = "007eJxTYJh/p92kNDFjaaJvj/9BBqXJv/o4P9+MPB0Zpft5csDqpkkKDGnmFompBhZJFmZm5ibmSQYWpmYmBgYpJmZJSWnJlqlJdqy5yQ2BjAxMr/IYGKEQxGdhyMnPL2BgAABJZx7x"
    var channelName = "loop"
    var joined: Bool = false
    var volume: Int = 50
    var isMuted: Bool = false
    var remoteUid: UInt = 0
    let screenShareExtensionName = "screenSharer"
    private var initialCenter: CGPoint = .zero
    
    var isStart : Bool  = true {
        didSet{
            if isStart {
                btnMic.isHidden = true
                btnVideo.isHidden = true
                btnCamera.isHidden = true
                btnRecord.isHidden = true
                imgMuteMic.isHidden = true
                imgMuteVideo.isHidden = true
                lblLocalMicMuted.isHidden = true
                lblLocalVideoPaused.isHidden = true
            }else{
                btnMic.isHidden = false
                btnVideo.isHidden = false
                btnCamera.isHidden = false
                btnRecord.isHidden = false
                imgMuteMic.isHidden = true
                imgMuteVideo.isHidden = true
                lblLocalMicMuted.isHidden = true
                lblLocalVideoPaused.isHidden = true
            }
        }
    }
    
    var isMicOn : Bool  = true {
        didSet{
            if isMicOn {
                btnMic.setImage(UIImage(named: "mic"), for: .normal)
                imgMuteMic.isHidden = true
                agoraEngine.muteLocalAudioStream(false)
                lblLocalMicMuted.isHidden = true
            }else{
                btnMic.setImage(UIImage(named: "mute"), for: .normal)
                imgMuteMic.isHidden = false
                agoraEngine.muteLocalAudioStream(true)
                lblLocalMicMuted.isHidden = false
            }
        }
    }
    var isVideoOn : Bool  = true {
        didSet{
            if isVideoOn {
                btnVideo.setImage(UIImage(named: "video"), for: .normal)
                imgMuteVideo.isHidden = true
                agoraEngine.muteLocalVideoStream(false)
                agoraEngine.startPreview()
                lblLocalVideoPaused.isHidden = true
                
            }else{
                btnVideo.setImage(UIImage(named: "muteVideo"), for: .normal)
                imgMuteVideo.isHidden = false
                agoraEngine.muteLocalVideoStream(true)
                agoraEngine.stopPreview()
                lblLocalVideoPaused.isHidden = false
            }
        }
    }
    var isRecordOn : Bool  = false {
        didSet{
            if isRecordOn {
                btnRecord.setImage(UIImage(named: "recStart"), for: .normal)
                print("True")
            }else{
                btnRecord.setImage(UIImage(named: "recEnd"), for: .normal)
                print("false")
            }
        }
    }
    
    //MARK: - LifeCycle
    override func viewDidLoad() {
        super.viewDidLoad()
        prepareScreenSharing()
        initializeAgoraEngine()
        initViews()
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
       
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("viewWillAppear")
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("viewDidAppear")
    }
    //MARK: - CustomMethod
    func joinChannel() {
        resetUIView()
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
            joinSuccess: { (channel, uid, elapsed) in
                print(channel)
                print(uid)
                print(elapsed)
            }
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
        // Check if leaving the channel was successful and set joined Bool accordingly
        if (result == 0) { joined = false }
    }
    func resetUIView(){
        isMicOn = true
        isVideoOn = true
    }
    func initializeAgoraEngine() {
        let config = AgoraRtcEngineConfig()
        // Pass in your App ID here.
        config.appId = appID
        // Use AgoraRtcEngineDelegate for the following delegate parameter.
        agoraEngine = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        //agoraEngine.setDefaultAudioRouteToSpeakerphone(speaker)
        
    }
    
    func initViews() {
        interfaceStack.heightAnchor.constraint(equalTo: btnCall.widthAnchor).isActive = true
        if !joined{
            isStart = true
        }
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
        agoraEngine.enableVideo()
        let view = UIView(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: LocalView.frame.size))
        localVideo = AgoraRtcVideoCanvas()
        localVideo!.view = view
        localVideo!.renderMode = .hidden
        localVideo!.uid = 0
        LocalView.addSubview(localVideo!.view!)
        agoraEngine.setupLocalVideo(localVideo)
        agoraEngine.startPreview()
        
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
    func stopRecording() {
        recorder.stopRecording { [unowned self] (preview, error) in
            print("Stopped recording")
            isRecordOn = false
            guard preview != nil else {
                print("Preview controller is not available.")
                return
            }
            let alert = UIAlertController(title: "Recording Finished", message: "Would you like to edit or delete your recording?", preferredStyle: .alert)
             
            let deleteAction = UIAlertAction(title: "Delete", style: .destructive, handler: { (action: UIAlertAction) in
                self.recorder.discardRecording(handler: { () -> Void in
                    print("Recording suffessfully deleted.")
                })
            })
             
            let editAction = UIAlertAction(title: "Edit", style: .default, handler: { (action: UIAlertAction) -> Void in
                preview?.previewControllerDelegate = self
                self.present(preview!, animated: true, completion: nil)
            })
            alert.addAction(editAction)
            alert.addAction(deleteAction)
            self.present(alert, animated: true, completion: nil)
            recorder.isMicrophoneEnabled = false
            self.isRecording = false
        }
        
    }
   
    @objc func startRecording() {
        print(recorder.isMicrophoneEnabled)
        recorder.startRecording(withMicrophoneEnabled: true){ [unowned self] (error) in
            guard error == nil else {
                print("Failed to start recording")
                return
            }
            if recorder.isRecording {
            print("Started Recording Successfully")
            isRecordOn = true
            self.isRecording = true
            }
                   
                   
    }
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
        if isMicOn{
            isMicOn = false
        }else{
            isMicOn = true
        }
        
    }
    @IBAction func btnRecordClick(_ sender: Any) {
        if !isRecording {
            startRecording()
        } else {
            stopRecording()
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
           isVideoOn = false
            
        }else{
           isVideoOn = true
            
            
        }
    }
    @IBAction func btnCallClick(_ sender: Any) {
        if !joined {
            joinChannel()
            // Check if successfully joined the channel and set button title accordingly
            if joined { btnCall.setImage(UIImage(named: "end"), for: .normal)
                isStart = false
                screenShareView.isHidden = false
            }
        } else {
            leaveChannel()
            removeFromParent(localVideo)
            localVideo = nil
            removeFromParent(remoteVideo)
            remoteVideo = nil
            if isRecording{
                stopRecording()
            }
            // Check if successfully left the channel and set button title accordingly
            if !joined { btnCall.setImage(UIImage(named: "call"), for: .normal)
               isStart = true
                screenShareView.isHidden = true
            }
        }
        
    }
}
@available(iOS 15.0, *)
extension VideoCallVC: AgoraRtcEngineDelegate {
    // Callback called when a new host joins the channel
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
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
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid:UInt, reason:AgoraUserOfflineReason) {
        if let it = remoteVideo, it.uid == uid {
            removeFromParent(it)
            remoteVideo = nil
        }
    }
    func rtcEngineConnectionDidLost(_ engine: AgoraRtcEngineKit) {
        print("Connection Lost")
    }
    func rtcEngine(_ engine: AgoraRtcEngineKit, didLeaveChannelWith stats: AgoraChannelStats) {
        print("sasdsd")
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
extension VideoCallVC: RPPreviewViewControllerDelegate {
    func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        dismiss(animated: true)
    }
}
