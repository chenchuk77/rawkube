# rawkube

### Creating a kubernetes cluster from scratch.
This project is a fork of the original [Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way).

Below is the complete steps that were taken to create a kubernetes cluster from scratch.


* create key-pair
  ```bash
  $ aws ec2 create-key-pair --key-name keypair-rawkube --query 'KeyMaterial' --output text > keypair-rawkube.pem --profile chen-dev-lumos
  $ chmod 400 keypair-rawkube.pem
  ```

* create 4 vms Debian 12 (bookworm), 2GB RAM, 30GB HDD
  ```bash
  aws ec2 run-instances \
    --image-id ami-0f482e737324c5ccf \
    --instance-type t4g.small \
    --count 4 --key-name keypair-rawkube \
    --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":30,"VolumeType":"gp3"}}]' \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=k8s-node}]' \
    --region eu-west-1 \
    --query 'Instances[*].InstanceId' \
    --output text --profile chen-dev-lumos
  ```
* provisioned vm's
  ```bash
  rawkube-jump, i-0c9330c8f81e2df10, t4g.small, 34.247.114.198, 172.31.6.20
  rawkube-m01,  i-02b39dfc1c765429e, t4g.small, 54.220.119.87,  172.31.11.103
  rawkube-w01,  i-096612b3152415aaf, t4g.small, 52.17.53.116,   172.31.0.61
  rawkube-w02,  i-004a045ea0fb1a04a, t4g.small, 54.76.215.169,  172.31.2.128
  ```

* connect to jumpbox and install packages
  ```bash
  $ ssh -i ./keypair-rawkube.pem admin@54.171.217.112                                                                                                                                ✔  13:54:03 
    admin@ip-172-31-6-20:~$
    admin@ip-172-31-6-20:~$ uname -mov
    #1 SMP Debian 6.1.112-1 (2024-09-30) aarch64 GNU/Linux
  $ sudo su -
  (root) $ apt-get update && apt-get -y install wget curl vim openssl git
  (root) $ git clone --depth 1 https://github.com/kelseyhightower/kubernetes-the-hard-way.git
  (root) $ mkdir downloads
  (root) $ wget -q --show-progress --https-only --timestamping -P downloads -i downloads.txt
  ```

* setup and verify kubectl
  ```bash
  (root) $ chmod +x downloads/kubectl
  (root) $ cp downloads/kubectl /usr/local/bin/
  (root) $ kubectl version --client
  ```
* manually create machines.txt with this content:
  ```bash
  172.31.11.103 rawkube-m01.kubernetes.local rawkube-m01
  172.31.0.61   rawkube-w01.kubernetes.local rawkube-w01 10.200.0.0/24
  172.31.2.128  rawkube-w02.kubernetes.local rawkube-w02 10.200.1.0/24
  ```
* enable root access via ssh for all nodes
  ```bash
  ssh admin@<PUBLIC_IP>
  sudo su -
  sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && systemctl restart sshd
  ```

* stopping/starting/checking VM state :
  ```bash
  ./rawkube.sh <start|stop|status>   
  ```

* Adding DNS resolving to all 4 VM's to `/etc/hosts` :
  ```bash
  # Rawkube (Kubernetes The Hard Way)
  172.31.11.103 rawkube-m01.kubernetes.local rawkube-m01
  172.31.0.61 rawkube-w01.kubernetes.local rawkube-w01
  172.31.2.128 rawkube-w02.kubernetes.local rawkube-w02
  ```
  
* Generate CA certificate on jump
  ```bash
  {
    openssl genrsa -out ca.key 4096
    openssl req -x509 -new -sha512 -noenc \
      -key ca.key -days 3653 \
      -config ca.conf \
      -out ca.crt
  }
  ```
* Generate clients certificates
  ```bash
  certs=(
    "admin" "rawkube-w01" "rawkube-w02"
    "kube-proxy" "kube-scheduler"
    "kube-controller-manager"
    "kube-api-server"
    "service-accounts"
  ) 
  for i in ${certs[*]}; do
    openssl genrsa -out "${i}.key" 4096
  
    openssl req -new -key "${i}.key" -sha256 \
      -config "ca.conf" -section ${i} \
      -out "${i}.csr"
    
    openssl x509 -req -days 3653 -in "${i}.csr" \
      -copy_extensions copyall \
      -sha256 -CA "ca.crt" \
      -CAkey "ca.key" \
      -CAcreateserial \
      -out "${i}.crt"
  done
  ```
* 04 - Upload clients certificates workers, then master)
  ```bash
  for host in rawkube-w01 rawkube-w02 ; do
    ssh root@$host mkdir /var/lib/kubelet/
    scp ca.crt root@$host:/var/lib/kubelet/
    scp $host.crt root@$host:/var/lib/kubelet/kubelet.crt
    scp $host.key root@$host:/var/lib/kubelet/kubelet.key
  done
  
  scp ca.key ca.crt \
    kube-api-server.key kube-api-server.crt \
    service-accounts.key service-accounts.crt \
    root@rawkube-m01:~/
  
  ```

* 05 - 

