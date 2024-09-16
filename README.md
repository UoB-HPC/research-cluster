# UoB HPC group research cluster

This repo contains a fully automated build steps of UoB HPC group's private research cluster.
The build scripts can be used to create a standalone heterogeneous research cluster from scratch.

### Development environment setup

This section is written against a Fedora host environment, you may need to adjust accordingly for other Linux distro.

1. Vagrant

    ```shell
    sudo dnf install @vagrant libvirt-devel
    sudo systemctl enable --now libvirtd
    sudo gpasswd -a ${USER} libvirt
    newgrp libvirt # enable group for current shell, logout to apply globally
    vagrant plugin install vagrant-libvirt
    ```

    For more details on setting Vagrant and libvirt, see <https://developer.fedoraproject.org/tools/vagrant/vagrant-libvirt.html>.

2. Ansible >= 2.5 (`import_role`, etc)

    Install Ansible and passlib via pip:

    ```shell
    sudo dnf install python3-pip
    python3 -m pip install --user ansible passlib
    ```

    Alternatively, using pipx:

    ```shell
    pipx install ansible
    pipx inject ansible passlib
    ```

    See <https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html> for more installation methods.

3. Optional: Ruby development

    To setup VSCode compatible LSP for Ruby:

    ```shell
    sudo dnf install ruby-devel
    gem install solargraph
    # Append $HOME/bin to PATH
    ```

    Then install the Ruby Solargraph VSCode plugin, enable the formatting option in settings.



### Testing the build

In project root, run 

```shell
ansible-galaxy install -r requirements.yml
```
The proceed to build the proxmox vagrant box:
```shell
cd proxmox
make build-libvirt
vagrant box add -f proxmox-ve-amd64 proxmox-ve-amd64-libvirt.box.json 
```
And the the OS images
```shell
cd images
make all -j $(nproc)
```
Finally, spin up the entire cluster in the Vagrant VM:
```
vagrant up
```
Individual provison steps can be executed via:
```
vagrant provision --provision-with=<STEP>
```
Available steps are all `playbooks-*.yml` files, omit the `playbook-` prefix when specyfing provision step (e.g `--provision-with=vm-router`)

Finally, stop or destroy the VM:
```
vagrant halt # use destroy to delete
```

# Deploying

First create an inventory file:

```yaml
---
ungrouped:
  hosts:
    pve:
      ansible_ssh_host: <YOUR_UNIQUE_IP_ADDR_FOR_PVE>
      ansible_ssh_port: 22
      ansible_ssh_user: "root"
      ansible_ssh_private_key_file: "<PATH_TO_PRIVATE_KEY>"
    idm.zoo.local:
      ansible_host: <YOUR_UNIQUE_IP_ADDR_FOR_THIS_NODE>
      ansible_port: 22
      ansible_user: root
      ansible_ssh_extra_args: -o ProxyCommand="ssh -W %h:%p root@<YOUR_UNIQUE_IP_ADDR_FOR_PVE>"
      ansible_ssh_private_key_file: "<PATH_TO_PRIVATE_KEY>"
    mgmt.zoo.local:
      ansible_host: <YOUR_UNIQUE_IP_ADDR_FOR_THIS_NODE>
      ansible_port: 22
      ansible_user: root
      ansible_ssh_extra_args: -o ProxyCommand="ssh -W %h:%p root@<YOUR_UNIQUE_IP_ADDR_FOR_PVE>"
      ansible_ssh_private_key_file: "<PATH_TO_PRIVATE_KEY>"
    login-amd64.zoo.local:
      ansible_host: <YOUR_UNIQUE_IP_ADDR_FOR_THIS_NODE>
      ansible_port: 22
      ansible_user: root
      ansible_ssh_extra_args: -o ProxyCommand="ssh -W %h:%p root@<YOUR_UNIQUE_IP_ADDR_FOR_PVE>"
      ansible_ssh_private_key_file: "<PATH_TO_PRIVATE_KEY>"
    login-arm64.zoo.local:
      ansible_host: <YOUR_UNIQUE_IP_ADDR_FOR_THIS_NODE>
      ansible_port: 22
      ansible_user: root
      ansible_ssh_extra_args: -o ProxyCommand="ssh -W %h:%p root@<YOUR_UNIQUE_IP_ADDR_FOR_PVE>"
      ansible_ssh_private_key_file: "<PATH_TO_PRIVATE_KEY>"
  vars:
    domain: <YOUR_DOMAIN>
    admin_email: "<YOUR_ADMIN_EMAIL>"
    postfix_smtp_relay: "<MY_SMTP_RELAY>" # run `nslookup -type=mx <domain of email> 8.8.8.8` to find out
    unattended_security_update_interval: "Mon *-*-1..7 00:00:00"
    srun_port_range: 60001-65000
    storage_pool: local-lvm
    ssh_private_key: "<PATH_TO_PRIVATE_KEY>"
    arch_to_dns_map:
      x86_64: amd64
      aarch64: arm64
    pve_username: root@pam
    pve_password: vagrant
    pve_node: pve
    router_host: router
    router_password: <YOUR_PASSWORD>
    router_disk_size: 6G
    router_mem_gb: 2
    router_ncores: 6
    router_ip:  <YOUR_UNIQUE_IP_ADDR_FOR_THIS_NODE>
    router_mgmt_ip:  <YOUR_UNIQUE_IP_ADDR_FOR_THIS_NODE_MGMT_ONLY>
    router_mgmt_dhcp_start: 10.10.20.2 # private DHCP IP range start
    router_mgmt_dhcp_end: 10.10.20.254 # private DHCP IP range end
    router_dns1: 1.1.1.1
    router_dns2: 8.8.8.8
    idm_host: idm
    idm_password: <YOUR_PASSWORD>
    idm_disk_size: 10G
    idm_mem_gb: 4
    idm_ncores: 6
    idm_sshkeys: <YOUR_KEYS>
    idm_ip: <YOUR_UNIQUE_IP_ADDR_FOR_THIS_NODE>
    ipa_password: <YOUR_PASSWORD>
    idm_default_group: cluster-user
    mgmt_host: mgmt
    mgmt_password: <YOUR_PASSWORD>
    mgmt_disk_size: 20G
    mgmt_mem_gb: 2
    mgmt_ncores: 6
    mgmt_sshkeys: <YOUR_KEYS>
    mgmt_rds_disk: "/dev/disk/by-id/<YOUR_DISK_LABEL>"
    mgmt_ip: <YOUR_UNIQUE_IP_ADDR_FOR_THIS_NODE>
    mgmt_netmask: 255.255.255.0
    mgmt_network: <YOUR_UNIQUE_IP_ADDR_FOR_THIS_NODE_MGMT_ONLY>
    mgmt_compute_dhcp_start: 10.20.30.210 # private DHCP IP range start
    mgmt_compute_dhcp_end: 10.20.30.250 # private DHCP IP range starendt
    mgmt_webhook_port: "8081"
    mgmt_exported_directories:
      - home
      - shared
    mgmt_cluster_name: staging
    login_message_of_the_day: <YOUR_MOTD>
    login_password: <YOUR_PASSWORD>
    login_disk_size: 10G
    login_mem_gb: 2
    login_ncores: 6
    login_sshkeys: <YOUR_KEYS>
    login_ip_from_arch_map:
      x86_64: "10.70.50.103"
      aarch64: "10.70.50.104"
    all_arch:
      - x86_64
      - aarch64
    nodes:
      compute0.zoo.local:
        ip: 10.70.50.220
        mac: BC:24:11:79:07:78
        pve: host
        image: cos_x86_64
        overlays:
          - wwinit
          - generic
          - arch-x86_64
        sockets: 1
        threads_per_core: 1
        cores_per_socket: 4
        pve_disk_size: 1G
        pve_mem_gb: 6
        pve_ncores: 4
      compute1.zoo.local:
        ip: 10.70.50.221
        mac: BC:24:11:79:07:79
        pve: aarch64
        image: cos_aarch64
        overlays:
          - wwinit
          - generic
          - arch-aarch64
        sockets: 1
        threads_per_core: 1
        cores_per_socket: 4
        pve_disk_size: 1G
        pve_mem_gb: 6
        pve_ncores: 4
      compute-ext0.zoo.local:
        ip: 10.70.50.222
        mac: 48:2A:E3:75:F0:1A
        image: cos_x86_64
        overlays:
          - wwinit
          - generic
          - arch-x86_64
        sockets: 1
        threads_per_core: 1
        cores_per_socket: 6
      compute-ext1.zoo.local:
        ip: 10.70.50.223
        mac: DC:A6:32:08:62:FA
        image: cos_aarch64
        overlays:
          - wwinit
          - generic
          - arch-aarch64
        sockets: 1
        threads_per_core: 1
        cores_per_socket: 4
    users:
      foo:
        first: Foo
        last: Bar
        email: foo.bar@example.com
        publickey:
          - <THE_KEY>
```

Proceed to run the playbook:

```shell
ansible-playbook -i my_inventory.yml playbook-all.yml --extra-vars="domain=<YOUR_DOMAIN>"
```






