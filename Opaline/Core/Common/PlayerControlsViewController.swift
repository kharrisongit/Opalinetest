import UIKit

final class PlayerControlsViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "player.controls.title".localized
        tableView.backgroundColor = ThemeManager.shared.background
        tableView.separatorColor = ThemeManager.shared.separator
        tableView.tableFooterView = UIView()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        PlayerControl.allCases.count
    }

    override func tableView(
        _ tableView: UITableView, titleForFooterInSection section: Int
    ) -> String? {
        "player.controls.footer".localized
    }

    override func tableView(
        _ tableView: UITableView, cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let control = PlayerControl.allCases[indexPath.row]
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = control.title
        cell.textLabel?.textColor = ThemeManager.shared.primaryText
        cell.backgroundColor = ThemeManager.shared.surface
        cell.selectionStyle = .none
        let toggle = UISwitch()
        toggle.tag = indexPath.row
        toggle.isOn = control.isVisible
        toggle.onTintColor = ThemeManager.shared.accent
        toggle.accessibilityLabel = control.title
        toggle.addTarget(self, action: #selector(changed(_:)), for: .valueChanged)
        cell.accessoryView = toggle
        return cell
    }

    @objc
    private func changed(_ sender: UISwitch) {
        guard PlayerControl.allCases.indices.contains(sender.tag) else {
            return
        }
        PlayerControl.allCases[sender.tag].isVisible = sender.isOn
    }
}
