//
//  CajeroViewController.swift
//  RAVNU_Proyecto
//
//  Created by XCODE on 8/04/26.
//

import UIKit

class CajeroViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func btnSalir(_ sender: UIButton) {
        cerrarSesionUniversal()
    }
}
