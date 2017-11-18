//
//  ObjectRecognizer.swift
//  CoreMLApp
//
//  Created by Rodrigo Morbach on 16/11/17.
//  Copyright © 2017 Rodrigo Morbach. All rights reserved.
//

import UIKit

class ObjectRecognizer: NSObject {
    
    let model = MobileNet()
    
    func predict(image: CVPixelBuffer)->String?{
        do{
            let input = MobileNetInput(image: image);
            let result = try self.model.prediction(input: input)
            return result.classLabel;
        }catch{
            
        }
        return nil
    }
    
}
