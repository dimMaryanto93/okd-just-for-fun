# Deploying OKD on Nutanix cluster

Design untuk meng-implementasikan OKD dengan production grade yang akan kita buat seperti berikut:

![grand-design](../../../docs/images/day-0/01a-overview-upi-ntnx-design.png)

Komponent yang di butuhkan adalah

| Component | Version | Mandatory | Description |
| :---      | :---      | :---      | :---  |
| Prism Element | `>= 6.10.x` | `yes` |    |
| Prism Central | `2023.6.x`   | `yes`  |  |
| Bastion       | `Fedora coreos 8` / `Redhat 8` | `yes` | |
| Registry      | compatible private registry | `optional` |  if you want to use darkside mode then ***private registry is required*** | 