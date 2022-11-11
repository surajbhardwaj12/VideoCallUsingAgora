//
//  HomePageVC.swift
//  VideoCallWithAgora
//
//  Created by IPS-161 on 11/11/22.
//

import UIKit

class HomePageVC: UIViewController {

    @IBOutlet weak var btnJoin: UIButton!
    @IBOutlet weak var txtChannel: UITextField!
    @IBOutlet weak var txtToken: UITextField!
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    // MARK: - Navigation

    @IBAction func btnJoinClick(_ sender: Any) {
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyBoard.instantiateViewController(withIdentifier: "VideoCallVC") as! VideoCallVC
        vc.joinChannel()
        self.navigationController?.pushViewController(vc, animated: true)
    }
}
