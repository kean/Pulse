//
//  ViewController.swift
//  pulse-demo
//
//  Created by Alexander Grebenyuk on 20.08.2021.
//

import UIKit
import PulseUI
import PulseCore
import SwiftUI

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    let tableView = UITableView()
    var ds: AnyObject?

    var items: [MenuItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        #warning("TODO: add proper mocks")
        
        for _ in 0...100 {
            PulseCore.LoggerStore.default.storeMessage(label: "test", level: .debug, message: "test", metadata: nil, file: "dsad", function: "hey", line: 1)
        }

        #warning("TODO: add dimiss")

        items = [
            MenuItem(title: "Main", action: { [unowned self] in
                let vc = MainViewController()
                self.present(vc, animated: true, completion: nil)
            }),
            MenuItem(title: "Main (Fullscreen)", action: { [unowned self] in
                let vc = MainViewController()
                vc.modalPresentationStyle = .fullScreen
                self.present(vc, animated: true, completion: nil)
            }),
            MenuItem(title: "Console", action: { [unowned self] in
                let vc = UIHostingController(rootView: ConsoleView())
                self.navigationController?.pushViewController(vc, animated: true)
            }),
            MenuItem(title: "Network", action: { [unowned self] in
                let vc = UIHostingController(rootView: NetworkView())
                self.navigationController?.pushViewController(vc, animated: true)
            }),
            MenuItem(title: "Pins", action: { [unowned self] in
                let vc = UIHostingController(rootView: PinsView())
                self.navigationController?.pushViewController(vc, animated: true)
            })
        ]

        view.addSubview(tableView)

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "a")

        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.rightAnchor.constraint(equalTo: view.rightAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leftAnchor.constraint(equalTo: view.leftAnchor)
        ])

        tableView.dataSource = self
        tableView.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if let row = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: row, animated: true)
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "a", for: indexPath)
        let item = items[indexPath.row]
        cell.textLabel?.text = item.title
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = items[indexPath.row]
        item.action()
    }
}

struct MenuItem {
    let title: String
    let action: () -> Void
}
