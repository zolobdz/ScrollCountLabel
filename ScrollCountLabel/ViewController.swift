//
//  ViewController.swift
//  Demo
//
//  Created by zolobdz on 2020/3/24.
//  Copyright © 2020 zolobdz. All rights reserved.
//

import UIKit


class ViewController: UIViewController {
    
    lazy var countLabel: ScrollingLabel = {
        let label = ScrollingLabel()
        label.font = UIFont.systemFont(ofSize: 32)
        return label
    }()
    
    @IBOutlet weak var numberTextField: UITextField!
    
    @IBOutlet weak var animationFlagButton: UIButton!
    @IBOutlet weak var durationTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(countLabel)
        countLabel.backgroundColor = .black
        countLabel.frame = CGRect(x: 0, y: 100, width: 375, height: 40)
//        countLabel.config("76543219.11", interval: 10, animate: false)
        countLabel.config("0", interval: 10, animate: false)
        countLabel.clipsToBounds = true
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
//        countLabel.config("1310.11", interval: 10, animate: false)
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//            self.countLabel.config("00", interval: 10, animate: true)
//        }
    }
    
    @IBAction func animationFlagButtonAtion(_ sender: UIButton) {
        animationFlagButton.isSelected = !animationFlagButton.isSelected
    }
    
    @IBAction func changeNumberAction(_ sender: UIButton) {
        guard let targetNumber = numberTextField.text,let _ = Double(targetNumber) else { return }
        let duration = TimeInterval(durationTextField.text ?? "0") ?? 0.0
        countLabel.config(targetNumber, interval: duration, animate: animationFlagButton.isSelected)
        
    }
    
    
}

