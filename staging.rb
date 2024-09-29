require 'yaml'

module Staging
  private_class_method def self.stringify_all_keys(hash)
    result = {}
    hash.each do |k, v|
      result[k.to_s] =
        case v
        when Hash then stringify_all_keys(v)
        when Array then v.map { |x| x.is_a?(Hash) ? stringify_all_keys(x) : x }
        else v
        end
    end
    result
  end

  def self.host_inventory_block(ip, private_key, common = {})
    {
      "ansible_host": ip,
      "ansible_port": 22,
      "ansible_user": 'root',
      "ansible_ssh_private_key_file": private_key
    }.merge(common)
  end

  DOMAIN = 'staging.local'.freeze
  VM_CPU = 4
  VM_MEMORY_GB = 14.5
  VM_ROOT_DISK_SIZE_GB =
    12 + # mgmt
    6 + # router
    (10 * 2) + #  idm, login
    (1 * 2) # compute

  VM_RDS1_DISK_SIZE_GB = 1

  SSH_PUBLIC_KEY = "#{Dir.home}/.ssh/id_ed25519.pub".freeze
  SSH_PRIVATE_KEY = "#{Dir.home}/.ssh/id_ed25519".freeze

  def self.common_vars(storage_pool)
    {
      domain: DOMAIN,
      admin_email: "root@#{DOMAIN}",
      postfix_smtp_relay: 'localhost',
      unattended_security_update_interval: 'Mon *-*-1..7 00:00:00',
      srun_port_range: '60001-65000',
      storage_pool: storage_pool,
      test_ssh_private_key: SSH_PRIVATE_KEY,
      delete_templates: true,
      arch_to_dns_map: {
        x86_64: 'amd64',
        aarch64: 'arm64'
      },
      disk_format: 'qcow2'
    }
  end

  def self.write_inventory(pve_ip:, storage_pool:, extra_hosts:, host_common_hash:, path:)
    raise "Public key file #{SSH_PUBLIC_KEY} not found" unless File.file?(SSH_PUBLIC_KEY)
    raise "Public key file #{SSH_PRIVATE_KEY} not found" unless File.file?(SSH_PRIVATE_KEY)

    ssh_pub_keys = [File.read(SSH_PUBLIC_KEY).strip, "#{File.read(SSH_PUBLIC_KEY).strip}_copy"]
    test_password = 'vagrant0' # IPA needs >= 8 characters
    ssh_keys = ssh_pub_keys
    pve_vars = {
      pve_username: 'root@pam',
      pve_password: 'vagrant',
      pve_node: 'pve'
    }
    router_node_vars = {
      router_host: 'router',
      router_password: test_password,
      router_sshkeys: ssh_keys,
      router_disk_size: '6G',
      router_mem_gb: 2,
      router_ncores: 4,
      router_inet_wan: 'vmbr0',
      router_inet_lan: 'vmbr1',
      router_inet_mgmt: 'vmbr2',
      router_ip: '10.10.10.10',
      router_mgmt_ip: '10.10.20.1',
      router_mgmt_dhcp_start: '10.10.20.2',
      router_mgmt_dhcp_end: '10.10.20.254',
      router_dns1: '1.1.1.1',
      router_dns2: '8.8.8.8'
    }
    idm_node_vars = {
      idm_host: 'idm',
      idm_password: test_password,
      idm_sshkeys: ssh_keys,
      idm_disk_size: '10G',
      idm_mem_gb: 4,
      idm_ncores: 4,
      idm_ip: '10.10.10.101',
      ipa_password: test_password,
      idm_default_group: 'cluster-user'
    }
    mgmt_node_vars = {
      mgmt_host: 'mgmt',
      mgmt_password: test_password,
      mgmt_sshkeys: ssh_keys,
      mgmt_disk_size: '24G',
      mgmt_mem_gb: 2,
      mgmt_ncores: 4,
      mgmt_rds_disk: '/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_rds1',
      mgmt_rds_part: '/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_rds1-part1',
      mgmt_rds_fstype: 'xfs',
      mgmt_rds_opts: 'uquota',
      mgmt_ip: '10.10.10.102',
      # following are only used for warewulf config generation
      mgmt_netmask: '255.255.255.0',
      mgmt_network: '10.10.10.0',
      mgmt_compute_dhcp_start: '10.10.10.150',
      mgmt_compute_dhcp_end: '10.10.10.254',
      mgmt_webhook_port: '808',
      mgmt_exported_directories: %w[home shared opt],
      mgmt_cluster_name: 'staging'
    }
    login_node_vars = {
      login_message_of_the_day: 'Login node MOTD',
      login_password: test_password,
      login_sshkeys: ssh_keys,
      login_disk_size_from_arch_map: {
        x86_64: '10G',
        aarch64: '10G'
      },
      login_ncores_from_arch_map: {
        x86_64: 4,
        aarch64: 4
      },
      login_mem_gb_from_arch_map: {
        x86_64: 2,
        aarch64: 2
      },
      login_ip_from_arch_map: {
        x86_64: '10.10.10.103',
        aarch64: '10.10.10.104'
      },
      login_type_from_arch_map: {
        x86_64: 'pve@localhost',
        aarch64: 'pve@localhost'
      }
    }

    partitions = {
      host: {
        max_time: '1-00:00:00',
        extra: 'Default=YES'
      },
      arm: {
        max_time: '0-03:00:00',
        extra: ''
      }
    }

    compute_nodes = {
      "compute0.#{DOMAIN}": {
        ip: '10.10.10.150',
        mac: 'BC:24:11:79:07:78',
        mgmt_ip: '10.10.20.150',
        mgmt_mac: 'BC:24:11:79:08:78',
        pve: 'host',
        image: 'cos_plain.x86_64',
        overlays: %w[wwinit generic arch-x86_64],
        sockets: 1,
        threads_per_core: 1,
        cores_per_socket: 4,
        pve_disk_size: '1G',
        pve_mem_gb: 10, # Otherwise iPXE runs out of memory decompressing initramfs
        pve_ncores: 4,
        partition: 'host'
      },
      "compute1.#{DOMAIN}": {
        ip: '10.10.10.151',
        mac: 'BC:24:11:79:07:79',
        mgmt_ip: '10.10.20.151',
        mgmt_mac: 'BC:24:11:79:08:79',
        pve: 'aarch64',
        image: 'cos_plain.aarch64',
        overlays: %w[wwinit generic arch-aarch64],
        sockets: 1,
        threads_per_core: 1,
        cores_per_socket: 4,
        pve_disk_size: '1G',
        pve_mem_gb: 10, # Otherwise iPXE runs out of memory decompressing initramfs
        pve_ncores: 4,
        partition: 'arm'
      }
    }

    common_vars = common_vars(storage_pool)
    extra_inventory = {
      "ungrouped": {
        "hosts":
        extra_hosts.merge(
          "router.#{DOMAIN}": host_inventory_block(router_node_vars[:router_ip], SSH_PRIVATE_KEY, host_common_hash),
          "idm.#{DOMAIN}": host_inventory_block(idm_node_vars[:idm_ip], SSH_PRIVATE_KEY, host_common_hash),
          "mgmt.#{DOMAIN}": host_inventory_block(mgmt_node_vars[:mgmt_ip], SSH_PRIVATE_KEY, host_common_hash)
        ).merge(
          %w[x86_64 aarch64].map do |arch|
            name = common_vars[:arch_to_dns_map][arch.to_sym]
            ip = login_node_vars[:login_ip_from_arch_map][arch.to_sym]
            ["login-#{name}.#{DOMAIN}", host_inventory_block(ip, SSH_PRIVATE_KEY, host_common_hash)]
          end.to_h
        ),
        "vars": common_vars.merge(
          pve_vars,
          router_node_vars,
          idm_node_vars,
          mgmt_node_vars,
          login_node_vars
        ).merge(
          "all_arch": %w[x86_64 aarch64],
          "partitions": partitions,
          "nodes": compute_nodes,
          "users": {
            "foo": {
              "first": 'foo',
              "last": 'foo',
              "email": 'foo@example.com',
              "publickey": ssh_keys,
              "group": ''
            },
            "bar": {
              "first": 'bar',
              "last": 'bar',
              "email": 'bar@example.com',
              "publickey": ssh_keys,
              "group": 'sudo'
            }
          }
        )
      }
    }
    File.write(path, stringify_all_keys(extra_inventory).to_yaml(line_width: -1))
  end
end

if __FILE__ == $PROGRAM_NAME
  ignore_hostkey_args = '-o StrictHostKeychecking=no -o UserKnownHostsFile=/dev/null'
  pve_ip = '10.10.8.2'
  Staging.write_inventory(
    pve_ip: pve_ip,
    storage_pool: 'local',
    extra_hosts: {
      pve: Staging.host_inventory_block(
        pve_ip,
        Staging::SSH_PRIVATE_KEY,
        { ansible_ssh_extra_args: ignore_hostkey_args }
      )
    },
    host_common_hash: {
      ansible_ssh_extra_args: "#{ignore_hostkey_args} -o ProxyCommand=\"ssh #{ignore_hostkey_args} -W %h:%p root@#{pve_ip}\""
    },
    path: ARGV[0]
  )
end
