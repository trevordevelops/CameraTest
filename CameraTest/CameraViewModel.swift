//
//  UserEvents.swift
//  CameraTest
//
//  Created by Trevor Welsh on 2/16/22.
//

import SwiftUI
import AVFoundation
import Photos

class CameraViewModel: NSObject, ObservableObject {
	@Published var applicationName: String = ""
	@Published var preferredStartingCameraType: AVCaptureDevice.DeviceType = AVCaptureDevice.DeviceType.builtInWideAngleCamera
	@Published var preferredStartingCameraPosition: AVCaptureDevice.Position = AVCaptureDevice.Position.back
	@Published var videoQuality: AVCaptureSession.Preset = .high
	@Published var flashMode: AVCaptureDevice.FlashMode = .off
	@Published var focusImage: String?
	@Published var videoGravity: AVLayerVideoGravity = .resizeAspectFill
	@Published var tappedFocusPoint: CGPoint? = nil
	@Published  var session = AVCaptureSession()
	@Published var photoOutput: AVCapturePhotoOutput = AVCapturePhotoOutput()
	@Published var movieFileOutput: AVCaptureMovieFileOutput = AVCaptureMovieFileOutput()
	private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera], mediaType: .video, position: .unspecified)
	@Published var cameraPreview: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer()
	private var currentZoomFactor: CGFloat = 1
	private var backgroundRecordingID: UIBackgroundTaskIdentifier?
	private var videoDeviceInput: AVCaptureDeviceInput!
	private var setupResult: SessionSetupResult = .success
	private let sessionQueue = DispatchQueue(label: "session queue")
	private enum SessionSetupResult {
		case success
		case notAuthorized
		case configurationFailed
	}
	
	public func checkForCameraPermissions() {
		switch AVCaptureDevice.authorizationStatus(for: .video) {
			case .authorized:
				// The user has previously granted access to the camera.
//				session.startRunning()
				break
			case .notDetermined:
				sessionQueue.suspend()
				AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
					if !granted {
						self.setupResult = .notAuthorized
					}
					self.sessionQueue.resume()
				})
			default:
				setupResult = .notAuthorized
		}
		sessionQueue.async {
			self.configureSession()
		}
	}
	
	private func configureSession() {
		if setupResult != .success {
			return
		}
		self.session.beginConfiguration()
		self.session.sessionPreset = .high
		do {
			var defaultVideoDevice: AVCaptureDevice?
			if let preferredCameraDevice = AVCaptureDevice.default(self.preferredStartingCameraType, for: .video, position: self.preferredStartingCameraPosition) {
				defaultVideoDevice = preferredCameraDevice
			} else if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
				defaultVideoDevice = dualCameraDevice
			} else if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
				defaultVideoDevice = backCameraDevice
			} else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
				defaultVideoDevice = frontCameraDevice
			}
			guard let videoDevice = defaultVideoDevice else {
				print("Default video device is unavailable.")
				setupResult = .configurationFailed
				self.session.commitConfiguration()
				return
			}
			let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
			if self.session.canAddInput(videoDeviceInput) {
				self.session.addInput(videoDeviceInput)
				DispatchQueue.main.async {
					self.videoDeviceInput = videoDeviceInput
				}
			} else {
				print("Couldn't add video device input to the self.ue.session.")
				setupResult = .configurationFailed
				self.session.commitConfiguration()
				return
			}
		} catch {
			print("Couldn't create video device input: \(error)")
			setupResult = .configurationFailed
			self.session.commitConfiguration()
			return
		}
		
		do {
			let audioDevice = AVCaptureDevice.default(for: .audio)
			let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice!)
			
			if self.session.canAddInput(audioDeviceInput) {
				self.session.addInput(audioDeviceInput)
			} else {
				print("Could not add audio device input to the session")
			}
		} catch {
			print("Could not create audio device input: \(error)")
		}
//		let photoOutput = AVCapturePhotoOutput()
		if self.session.canAddOutput(self.photoOutput) {
			self.session.addOutput(self.photoOutput)
//			self.photoOutput = photoOutput
		} else {
			print("Could not add photo output to the session")
			setupResult = .configurationFailed
			self.session.commitConfiguration()
			return
		}
//		let movieFileOutput = AVCaptureMovieFileOutput()
		if self.session.canAddOutput(self.movieFileOutput) {
			self.session.addOutput(self.movieFileOutput)
			if let connection = self.movieFileOutput.connection(with: AVMediaType.video) {
				if connection.isVideoStabilizationSupported {
					connection.preferredVideoStabilizationMode = .auto
				}
			}
//			self.movieFileOutput = movieFileOutput
		}
		self.session.commitConfiguration()
	}
	
	public func rotateCamera() {
		self.sessionQueue.async {
			let currentVideoDevice = self.videoDeviceInput?.device
			let currentPosition = currentVideoDevice?.position
			let preferredPosition: AVCaptureDevice.Position
			let preferredDeviceType: AVCaptureDevice.DeviceType
			switch currentPosition {
				case .unspecified, .none, .front:
					preferredPosition = .back
					preferredDeviceType = .builtInDualCamera
					
				case .back:
					preferredPosition = .front
					preferredDeviceType = .builtInTrueDepthCamera
					
				@unknown default:
					print("Unknown capture position. Defaulting to back, dual-camera.")
					preferredPosition = .back
					preferredDeviceType = .builtInDualCamera
			}
			let devices = self.videoDeviceDiscoverySession.devices
			var newVideoDevice: AVCaptureDevice? = nil
			if let device = devices.first(where: { $0.position == preferredPosition && $0.deviceType == preferredDeviceType }) {
				newVideoDevice = device
			} else if let device = devices.first(where: { $0.position == preferredPosition }) {
				newVideoDevice = device
			}
			
			if let videoDevice = newVideoDevice {
				do {
					let captureDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
					self.session.beginConfiguration()
					self.session.removeInput(self.videoDeviceInput!)
					// remove and re-add inputs and outputs
					//                    for input in self.self.ue.session.inputs {
					//                        self.self.ue.session.removeInput(input)
					//                    }
					if self.session.canAddInput(captureDeviceInput) {
						//                        NotificationCenter.default.removeObserver(self, name: .AVCaptureDeviceSubjectAreaDidChange, object: currentVideoDevice)
						//                        NotificationCenter.default.addObserver(self, selector: #selector(self.subjectAreaDidChange), name: .AVCaptureDeviceSubjectAreaDidChange, object: videoDeviceInput.device)
						self.session.addInput(captureDeviceInput)
						self.videoDeviceInput = captureDeviceInput
					} else {
						self.session.addInput(self.videoDeviceInput!)
					}
					if let connection = self.movieFileOutput.connection(with: .video) {
						if connection.isVideoStabilizationSupported {
							connection.preferredVideoStabilizationMode = .auto
						}
					}
					self.session.commitConfiguration()
				} catch {
					print("Error occurred while creating video device input: \(error)")
				}
			}
			//			DispatchQueue.main.async {
			//				self.ue.delegate?.didRotateCamera()
			//			}
		}
	}
	
	public func videoZoom(value: DragGesture.Value) {
		do {
			if abs(value.translation.height) > abs(value.translation.width) {
				let percentage: CGFloat = -(value.translation.height / UIScreen.main.bounds.height)
				let calc = currentZoomFactor + percentage
				let zoomFactor: CGFloat = min(max(calc, 1), 5)
				currentZoomFactor = zoomFactor
				let captureDevice = self.videoDeviceInput.device
				try captureDevice.lockForConfiguration()
				captureDevice.videoZoomFactor = currentZoomFactor
			}
		} catch {
			print("Error locking configuration for camera zoom")
		}
	}
	
	public func tapToFocus(tapLocation: CGPoint, viewSize: CGSize) {
		let x = tapLocation.y / viewSize.height
		let y = 1.0 - tapLocation.x / viewSize.width
		let focusPoint = CGPoint(x: x, y: y)
		do {
			let device = self.videoDeviceInput.device
			try device.lockForConfiguration()
			if device.isFocusPointOfInterestSupported == true {
				device.focusPointOfInterest = focusPoint
				device.focusMode = .autoFocus
			}
			device.exposurePointOfInterest = focusPoint
			device.exposureMode = AVCaptureDevice.ExposureMode.continuousAutoExposure
			device.unlockForConfiguration()
			DispatchQueue.main.async {
				self.tappedFocusPoint = focusPoint
			}
		} catch {
			print(error)
		}
	}
	
	public func toggleMovieRecording() {
		self.sessionQueue.async {
			if !self.movieFileOutput.isRecording {
				if UIDevice.current.isMultitaskingSupported {
					self.backgroundRecordingID = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
				}
				let movieFileOutputConnection = self.movieFileOutput.connection(with: .video)
				movieFileOutputConnection?.videoOrientation = .portrait
				let availableVideoCodecTypes = self.movieFileOutput.availableVideoCodecTypes
				if availableVideoCodecTypes.contains(.hevc) {
					self.movieFileOutput.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.hevc], for: movieFileOutputConnection!)
				}
				let outputFileName = NSUUID().uuidString
				let outputFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((outputFileName as NSString).appendingPathExtension("mov")!)
				self.movieFileOutput.startRecording(to: URL(fileURLWithPath: outputFilePath), recordingDelegate: self)
			} else {
				self.movieFileOutput.stopRecording()
			}
		}
	}
}

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
	public func takePhoto() {
		self.sessionQueue.async {
			let photoSettings = AVCapturePhotoSettings()
			if self.videoDeviceInput!.device.isFlashAvailable {
				photoSettings.flashMode = self.flashMode
			}
			photoSettings.flashMode = self.flashMode
			self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
		}
	}
	
	public func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
		DispatchQueue.main.async {
			// Flash the screen to signal that SwiftUICam took a photo.
//			self.view.layer.opacity = 0
//			UIView.animate(withDuration: 0.5) {
//				self.view.layer.opacity = 1
//			}
			//			self.ue.delegate?.didCapturePhoto()
			print("SUCCESS TAKING PHOTO")
		}
	}
	
	public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
		guard error == nil else { print("Error capturing photo: \(error!)"); return }

		if let photoData = photo.fileDataRepresentation() {
			let dataProvider = CGDataProvider(data: photoData as CFData)
			let cgImageRef = CGImage(jpegDataProviderSource: dataProvider!,
									 decode: nil,
									 shouldInterpolate: true,
									 intent: CGColorRenderingIntent.defaultIntent)

			// TODO: implement imageOrientation
			// Set proper orientation for photo
			// If camera is currently set to front camera, flip image
			//          let imageOrientation = getImageOrientation()

			// For now, it is only right
			let image = UIImage(cgImage: cgImageRef!, scale: 1, orientation: .right)
			//2 options to save
			//First is to use UIImageWriteToSavedPhotosAlbum
			savePhoto(image)
			//Second is adapting Apple documentation with data of the modified image
			//savePhoto(image.jpegData(compressionQuality: 1)!)
			DispatchQueue.main.async {
				//				self.ue.delegate?.didFinishProcessingPhoto(image)
			}
		}
	}
	
	private func savePhoto(_ image: UIImage) {
		UIImageWriteToSavedPhotosAlbum(image, self, #selector(didFinishSavingWithError(_:didFinishSavingWithError:contextInfo:)), nil)
	}
	
	@objc private func didFinishSavingWithError(_ image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: UnsafeRawPointer) {
		//		DispatchQueue.main.async {
		//			self.ue.delegate?.didFinishSavingWithError(image, error: error, contextInfo: contextInfo)
		//		}
	}
}

extension CameraViewModel: AVCaptureFileOutputRecordingDelegate {
	public func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
		DispatchQueue.main.async {
			//			self.ue.delegate?.didStartVideoRecording()
		}
	}
	
	/// - Tag: DidFinishRecording
	public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
		// Note: Because we use a unique file path for each recording, a new recording won't overwrite a recording mid-save.
		func cleanup() {
			let path = outputFileURL.path
			if FileManager.default.fileExists(atPath: path) {
				do {
					try FileManager.default.removeItem(atPath: path)
				} catch {
					print("Could not remove file at url: \(outputFileURL)")
				}
			}
			
			if let currentBackgroundRecordingID = backgroundRecordingID {
				backgroundRecordingID = UIBackgroundTaskIdentifier.invalid
				
				if currentBackgroundRecordingID != UIBackgroundTaskIdentifier.invalid {
					UIApplication.shared.endBackgroundTask(currentBackgroundRecordingID)
				}
			}
		}
		//		DispatchQueue.main.async {
		//			self.ue.delegate?.didFinishVideoRecording()
		//		}
		
		var success = true
		if error != nil {
			print("Movie file finishing error: \(String(describing: error))")
			success = (((error! as NSError).userInfo[AVErrorRecordingSuccessfullyFinishedKey] as AnyObject).boolValue)!
		}
		if success {
			// Check the authorization status.
			PHPhotoLibrary.requestAuthorization { status in
				if status == .authorized {
					// Save the movie file to the photo library and cleanup.
					PHPhotoLibrary.shared().performChanges({
						let options = PHAssetResourceCreationOptions()
						options.shouldMoveFile = true
						let creationRequest = PHAssetCreationRequest.forAsset()
						creationRequest.addResource(with: .video, fileURL: outputFileURL, options: options)
					}, completionHandler: { success, error in
						if !success {
							print("\(self.applicationName) couldn't save the movie to your photo library: \(String(describing: error))")
						}
						cleanup()
					}
					)
				} else {
					cleanup()
				}
			}
		} else {
			cleanup()
		}
	}
}
