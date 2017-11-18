//
//  ViewController.swift
//  CoreMLApp
//
//  Created by Rodrigo Morbach on 16/11/17.
//  Copyright © 2017 Rodrigo Morbach. All rights reserved.
//

import UIKit


class ViewController: UIViewController {

    let recognizer = ObjectRecognizer()
    
    var imagePickerControler: UIImagePickerController?
    
    @IBOutlet weak var result: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.imagePickerControler = UIImagePickerController(); 
        self.imagePickerControler?.sourceType = .camera;
        self.imagePickerControler?.allowsEditing = true;
        self.imagePickerControler?.delegate = self;
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    @IBAction func capture(_ sender: Any) {
        self.present(self.imagePickerControler!, animated: true, completion: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    func predict(image: CVPixelBuffer){
        if let result = recognizer.predict(image: image){
            self.result.text = result
        }
    }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate{
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]){
        if let image = info[UIImagePickerControllerEditedImage] as? UIImage{
            //ResizeImage
            let width = CGFloat(224);
            let height = CGFloat(224);
            
            if let newImage = image.resize(to: width, height: height){
                if let c = newImage.toCVPixelBuffer(){
                    self.predict(image: c);
                }
            }
        }
        
        self.imagePickerControler?.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController){
        self.imagePickerControler?.dismiss(animated: true, completion: nil);
    }
}



