//
//  CameraViewController.swift
//  CoreMLApp
//
//  Created by Rodrigo Morbach on 16/11/17.
//  Copyright © 2017 Rodrigo Morbach. All rights reserved.
//

import UIKit
import AVFoundation

class CameraViewController: UIViewController {
    
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    let recognizer = ObjectRecognizer()
    
    //Two threads (session queue and main)
    let semaphore = DispatchSemaphore(value: 2)
    
    @IBOutlet weak var previewView: PreviewView!
    
    @IBOutlet weak var resultLabel: UILabel!
    
    private var videoOutput = AVCaptureVideoDataOutput()
    
    private let session = AVCaptureSession()
    
    private var isSessionRunning = false;
    
    var videoDeviceInput: AVCaptureDeviceInput!
    
    private var setupResult: SessionSetupResult = .success
    
    private let sessionQueue = DispatchQueue(label: "session queue", qos: DispatchQoS.default, attributes: [], autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit, target: nil)
    
    private var videoCaptureInput: AVCaptureDeviceInput!;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        previewView.session = session
        
        self.sessionQueue.async {
            self.configureSession()
        }
        // Do any additional setup after loading the view.
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isSessionRunning{
            self.sessionQueue.async {
                self.session.stopRunning();
            }
        }
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        sessionQueue.async {
            switch self.setupResult {
            case .success:
                // Only setup observers and start the session running if setup succeeded.
                
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
                
            case .notAuthorized:
                DispatchQueue.main.async { [unowned self] in
                    let message = NSLocalizedString("cameraNotAuthorized", comment: "Alert message when the user has denied access to the camera")
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"), style: .`default`, handler: { action in
                        let url = URL(string: UIApplicationOpenSettingsURLString)
                        
                        UIApplication.shared.open(url!)
                    }))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
                
            case .configurationFailed:
                DispatchQueue.main.async { [unowned self] in
                    let message = NSLocalizedString("Unable to capture media", comment: "Alert message when something goes wrong during capture session configuration")
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func configureSession(){
        
        session.beginConfiguration();
        
        session.sessionPreset = AVCaptureSession.Preset.photo
        
        var defaultVideoDevice: AVCaptureDevice?
        defaultVideoDevice = CameraViewController.device(withMediaType: AVMediaType.video.rawValue, preferringPosition: .back)
        
        do{
            session.beginConfiguration()
            
            if session.canSetSessionPreset(AVCaptureSession.Preset.vga640x480)
            {
                session.sessionPreset = AVCaptureSession.Preset.vga640x480
            }
            session.commitConfiguration()
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: defaultVideoDevice!)
            
            self.videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String: NSNumber(value: kCVPixelFormatType_32BGRA)]
            
            self.videoOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)
            
            self.session.addOutput(self.videoOutput)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                
                DispatchQueue.main.async {
                    /*
                     Why are we dispatching this to the main queue?
                     Because AVCaptureVideoPreviewLayer is the backing layer for PreviewView and UIView
                     can only be manipulated on the main thread.
                     Note: As an exception to the above rule, it is not necessary to serialize video orientation changes
                     on the AVCaptureVideoPreviewLayer’s connection with other session manipulation.
                     
                     Use the status bar orientation as the initial video orientation. Subsequent orientation changes are
                     handled by CameraViewController.viewWillTransition(to:with:).
                     */
                    
                    let initialVideoOrientation: AVCaptureVideoOrientation = .portrait
                    
                    self.previewView.videoPreviewLayer.connection?.videoOrientation = initialVideoOrientation
                }
            }
            else {
                print("Could not add video device input to the session")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        }
        catch {
            print("Could not create video device input: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        session.commitConfiguration()
    }    
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate{
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("didOutput sample")
        semaphore.wait()
        //Try to create image    
        
        if let pixedBuffer = CMSampleBufferGetImageBuffer(sampleBuffer){
            let ciImage = CIImage.init(cvImageBuffer: pixedBuffer)
            let context = CIContext(options: nil)
            if let myImage = context.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(pixedBuffer), height: CVPixelBufferGetHeight(pixedBuffer))){
                
                let uiImage = UIImage(cgImage: myImage)
                let newImage = uiImage.resize(to: 224, height: 224)
                if let pixedImage = newImage?.toCVPixelBuffer(){
                    
                    DispatchQueue.main.async {
                        self.resultLabel.text = self.recognizer.predict(image: pixedImage)
                        self.semaphore.signal()
                    }
                }
            }
        }
    }
}


extension CameraViewController
{
    class func device(withMediaType: String, preferringPosition: AVCaptureDevice.Position)->AVCaptureDevice?
    {
        
        let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .back).devices
        print("devices:\(devices)")
        for device in devices where device.position == .back {
            return device
        }
        return nil
        
    }
    
}


