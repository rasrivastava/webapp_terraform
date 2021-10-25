Task 1 : Have to create/launch Application using Terraform
===========================================================

1. Create the key and security group which allow the port 80.
2. Launch EC2 instance.
3. In this Ec2 instance use the key and security group which we have created in step 1.
4. Launch one Volume (EBS) and mount that volume into /var/www/html
5. Developer have uploded the code into github repo also the repo has some images.
6. Copy the github repo code into /var/www/html
7. Create S3 bucket, and copy/deploy the images from github repo into the s3 bucket and change the permission to public readable.
8 Create a Cloudfront using s3 bucket(which contains images) and use the Cloudfront URL to  update in code in /var/www/html

- **Variable used in the main configuration file, user can edit as per there choice**

```
$ cat variables.tf 
variable profile_name {
    default = "rasrivasprofile"
}

variable ssh_key_name {
    default = "EC2KeyPair"
}

variable firewall_name {
    default = "MySecurityGroup"
}


variable ami_id {	
    default = "ami-0447a12f28fddb066"
}


variable instance_name {
    default = "MyWebServer"
}


variable bucket_name {
	default = "rasrivas-bucket-1234"
}


variable object_name {
    default = "image.jpg"
}
```

- **Script which will install the required packages for apache web server, PHP and git on the instance**

```
$ cat install_pkg_instance.sh 
#!/bin/bash

sudo yum install httpd php git -y
sudo systemctl restart httpd
sudo systemctl enable httpd
```

- **Script which will format and mount the persistent volume and clone the web pages to the apache root directroy on the instance**

```
$ cat ebs_vol_operation.sh 
#!/bin/bash

sudo mkfs.ext4  /dev/xvdh
sudo mount  /dev/xvdh  /var/www/html
sudo rm -rf /var/www/html/*
sudo git clone https://github.com/rasrivastava/tf_test.git /var/www/html/
```

- **Lets start the main configuration**


- **Reference**: https://www.terraform.io/docs/providers/aws/index.html
  - The Amazon Web Services (AWS) provider is used to interact with the many resources supported by AWS. The provider needs to be configured with the proper credentials before it can be used.

	```
	provider "aws" {
	    region = "ap-south-1"
	    profile = "${var.profile_name}"
	}
	```

- **Reference**: https://www.terraform.io/docs/providers/tls/r/private_key.html 
- **Resource**: *aws_key_pair*
  - Generates a secure private key and encodes it as PEM. This resource is primarily intended for easily bootstrapping throwaway development environments.
    - **algorithm** - (Required) The name of the algorithm to use for the key. Currently-supported values are "RSA" and "ECDSA".
    - **rsa_bits** - (Optional) When algorithm is "RSA", the size of the generated RSA key in bits. Defaults to 2048.
    - **ecdsa_curve** - (Optional) When algorithm is "ECDSA", the name of the elliptic curve to use. May be any one of "P224", "P256", "P384" or "P521", with "P224" as the default.

	```
	resource "tls_private_key" "private_key_pair" {
	    algorithm = "RSA"
	}
	```


- **Reference**: https://www.terraform.io/docs/providers/local/r/file.html
- **Resource**: *local_file*
  - Generates a local file with the given content.
    - **content** - (Optional) The content of file to create. Conflicts with sensitive_content and content_base64.
    - **filename** - (Required) The path of the file to create.
    - **file_permission** - (Optional) The permission to set for the created file. Expects an a string. The default value is "0777".

	```
	resource "local_file" "local_private_key" {
	    depends_on = [
			tls_private_key.private_key_pair
		]
	    content = tls_private_key.private_key_pair.private_key_pem
	    filename = 	"${var.ssh_key_name}.pem"
	    file_permission = "0400"
	}
	```


- **Refernece**: https://www.terraform.io/docs/providers/aws/r/key_pair.html
- **Resource**: *aws_key_pair*
  - Currently this resource requires an existing user-supplied key pair. This key pair public key will be registered with AWS to allow logging-in to EC2 instances.

    - **key_name**   - (Optional) The name for the key pair.
    - **key_name_prefix** - (Optional) Creates a unique name beginning with the specified prefix. Conflicts with key_name.
    - **public_key** - (Required) The public key material.
    - **tags** - (Optional) Key-value map of resource tags

	```
	resource "aws_key_pair" "key_pair" {
	    depends_on = [
			local_file.local_private_key
		]
	    key_name = var.ssh_key_name
	    public_key = tls_private_key.private_key_pair.public_key_openssh
	}
	```


- **Refernece**: https://www.terraform.io/docs/providers/aws/r/security_group.html
- **Resource**: aws_security_group
  - **name** - (Optional, Forces new resource) The name of the security group. If omitted, Terraform will assign a random, unique name 
  - **description** - (Optional, Forces new resource) The security group description.
  - **ingress** - (Optional) Can be specified multiple times for each ingress rule. Each ingress block supports fields documented below.
  - **egress** - (Optional, VPC only) Can be specified multiple times for each egress rule. Each egress block supports fields documented below.
    - The ingress/egress block supports:
      - **from_port** - (Required) The start port (or ICMP type number if protocol is "icmp" or "icmpv6")
      - **to_port** - (Required) The end range port (or ICMP code if protocol is "icmp").
      - **protocol** - (Required) The protocol. If you select a protocol of "-1" (semantically equivalent to "all", which is not a valid value here), you must specify a "from_port" and "to_port" equal to 0.
      - **cidr_blocks** - (Optional) List of CIDR blocks.

		```
		resource "aws_security_group" "firewall" {
		    depends_on = [
			aws_key_pair.key_pair
		    ]
		    name = var.firewall_name
		    description = "Allow HTTP and SSH inbound traffic"
		    ingress	{
			from_port = 80
			to_port = 80
			protocol = "tcp"
			cidr_blocks = ["0.0.0.0/0"]
		    }
		    ingress {
			from_port = 22
			to_port = 22
			protocol = "tcp"
			cidr_blocks = ["0.0.0.0/0"]
		    }
		    egress {
			from_port = 0
			to_port = 0
			protocol = "-1"
			cidr_blocks = ["0.0.0.0/0"]
		    }
		}
		```


- **Reference**: https://www.terraform.io/docs/providers/aws/r/instance.html
- **Resource**: *aws_instance*
  - Provides an EC2 instance resource. This allows instances to be created, updated, and deleted.
    - **ami** - (Required) The AMI to use for the instance. 
    - **instance_type** - (Required) The type of instance to start. Updates to this field will trigger a stop/start of the EC2 instance.
    - **key_name** - (Optional) The key name of the Key Pair to use for the instance; which can be managed using the aws_key_pair resource.
    - **security_groups** - (Optional, EC2-Classic and default VPC only) A list of security group names (EC2-Classic) or IDs (default VPC) to associate with.

- **Reference**: https://www.terraform.io/docs/provisioners/file.html
- **provisioner**: *file*
  - The file provisioner is used to copy files or directories from the machine executing Terraform to the newly created resource. The file provisioner supports both ssh and winrm type connections.
    - **source** - (Required) This is the source file or folder.
    - **destination** - (Required) This is the destination path.

- **Reference**: https://www.terraform.io/docs/provisioners/remote-exec.html
- **provisioner**: *remote-exec*
  - The remote-exec provisioner invokes a script on a remote resource after it is created. This can be used to run a configuration management tool, bootstrap into a cluster, etc.
    - **inline** - This is a list of command strings. They are executed in the order they are provided.

	```
	resource "aws_instance" "MyWebServer" {
	    depends_on = [
		aws_security_group.firewall,
	    ]
	    ami = var.ami_id
	    instance_type = "t2.micro"
	    key_name = var.ssh_key_name
	    security_groups = [ aws_security_group.firewall.name ]
	    tags = {
		Name = var.instance_name
	    }
	    connection {
		type = "ssh"
		user = "ec2-user"
		private_key = file("${var.ssh_key_name}.pem")
		host = aws_instance.MyWebServer.public_ip
	    }
	    provisioner "local-exec" {
		command = "echo ${aws_instance.MyWebServer.public_ip} > instance_public_ip.txt"
	    }
	    provisioner "file" {
		source = "install_pkg_instance.sh"
		destination = "/tmp/install_pkg_instance.sh"
	    }
	    provisioner "remote-exec" {
		inline = [
		    "chmod +x /tmp/install_pkg_instance.sh",
		    "/tmp/install_pkg_instance.sh args",
		]
	    }
	}
	```


- **Reference**: https://www.terraform.io/docs/providers/aws/r/ebs_volume.html
- **Resource**: *aws_ebs_volume*
  - **size** - (Optional) The size of the drive in GiBs.

	```
	resource "aws_ebs_volume" "hard_disk" {
	    depends_on = [
		aws_instance.MyWebServer
	    ]
	    availability_zone = aws_instance.MyWebServer.availability_zone
	    size = 1
	    tags = {
		Name = "MyWebServerVolume"
	  }
	}
	```


- **Reference**: https://www.terraform.io/docs/providers/aws/r/volume_attachment.html
- **Resource**: *aws_volume_attachment*
  - Provides an AWS EBS Volume Attachment as a top level resource, to attach and detach volumes from AWS Instances.
    - **device_name** - (Required) The device name to expose to the instance (for example, /dev/sdh or xvdh).
    - **volume_id** - (Required) ID of the Volume to be attached
    - **instance_id** - (Required) ID of the Instance to attach to
    - **force_detach** - (Optional, Boolean) Set to true if you want to force the volume to detach

	```
	resource "aws_volume_attachment" "ebs_vol_att" {
	    depends_on = [
		aws_ebs_volume.hard_disk
	    ]
	    device_name = "/dev/sdh"
	    volume_id   = aws_ebs_volume.hard_disk.id
	    instance_id = aws_instance.MyWebServer.id
	    force_detach = true
	}
	```


- **Format and mount the partition to the apache web server root direcrtory**

	```
	resource "null_resource" "attach_ebs_vol" {
	    depends_on = [
		aws_volume_attachment.ebs_vol_att
	    ]
	    connection {
		type = "ssh"
		user = "ec2-user"
		private_key = file("${var.ssh_key_name}.pem")
		host = aws_instance.MyWebServer.public_ip
	    }
	    provisioner "file" {
		source = "ebs_vol_operation.sh"
		destination = "/tmp/ebs_vol_operation.sh"
	    }
	    provisioner "remote-exec" {
		inline = [
		    "chmod +x /tmp/ebs_vol_operation.sh",
		    "/tmp/ebs_vol_operation.sh args",
		]
	    }
	}
	```

- **Download the images from the github remote**

	```
	resource "null_resource" "remote_img_download" {
	    depends_on = [
		null_resource.attach_ebs_vol
	    ]
	    provisioner "local-exec" {
		command = "git clone https://github.com/rasrivastava/tf_test.git web_image"
	  }
	}
	```


- **Create public-read S3 Bucket**

	```
	resource "aws_s3_bucket" "mys3bucket" {
	    depends_on = [
		null_resource.remote_img_download
	    ]
	    bucket = "${var.bucket_name}"
	    acl = "public-read"
	    tags = {
	      Name  = "s3_bucket"
	  }
	}
	```


- **Upload the image downloded from the remote github**

	```
	resource "aws_s3_bucket_object" "image_upload" {
	    depends_on = [
		aws_s3_bucket.mys3bucket
	    ]
	    key = var.object_name
	    bucket = "${var.bucket_name}"
	    acl    = "public-read"
	    source = "web_image/images/82597.jpg"
	}
	```


- **Reference**: https://www.terraform.io/docs/configuration/locals.html
- A local value assigns a name to an expression, allowing it to be used multiple times within a module without repeating it.

	```
	locals {
	    s3_origin_id = "S3-${aws_s3_bucket.mys3bucket.bucket}"
	}
	```


- **Reference**: https://www.terraform.io/docs/providers/aws/r/cloudfront_distribution.html
- **Resource**: *aws_cloudfront_distribution*
  - Creates an Amazon CloudFront web distribution.
    - **enabled** (Required) - Whether the distribution is enabled to accept end user requests for content.
    - **origin** (Required) - One or more origins for this distribution (multiples allowed).
    - **default_cache_behavior** (Required) - The default cache behavior for this distribution (maximum one).
      - **allowed_methods** (Required) - Controls which HTTP methods CloudFront processes and forwards to your Amazon S3 bucket or your custom origin.
      - **cached_methods** (Required) - Controls whether CloudFront caches the response to requests using the specified HTTP methods.
      - **target_origin_id** (Required) - The value of ID for the origin that you want CloudFront to route requests to when a request matches the path pattern either for a cache behavior or for the default cache behavior.
      - **forwarded_values** (Required) - The forwarded values configuration that specifies how CloudFront handles query strings, cookies and headers (maximum one).
        - **cookies** (Required) - The forwarded values cookies that specifies how CloudFront handles cookies (maximum one).
          - **forward** (Required) - Specifies whether you want CloudFront to forward cookies to the origin that is associated with this cache behavior. You can specify all, none or whitelist. If whitelist, you must include the subsequent whitelisted_names
           - **query_string** (Required) - Indicates whether you want CloudFront to forward query strings to the origin that is associated with this cache behavior.
      - **viewer_protocol_policy** (Required) - Use this element to specify the protocol that users can use to access the files in the origin specified by TargetOriginId when a request matches the path pattern in PathPattern. One of allow-all, https-only, or redirect-to-https.
      - **restrictions** (Required) - The restriction configuration for this distribution (maximum one).
        - **geo_restriction**
          - **restriction_type** (Required) - The method that you want to use to restrict distribution of your content by country: none, whitelist, or blacklist.
      - **viewer_certificate** (Required) - The SSL configuration for this distribution (maximum one).

	```
	resource "aws_cloudfront_distribution" "cloudfront" {
	    depends_on = [
		aws_s3_bucket_object.image_upload
	    ]
	    enabled = true
	    origin {
		domain_name = aws_s3_bucket.mys3bucket.bucket_domain_name
		origin_id = local.s3_origin_id
	    }
	    default_cache_behavior {
		    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
		    cached_methods   = ["GET", "HEAD"]
		    target_origin_id = local.s3_origin_id
		    forwarded_values {
			query_string = false
			cookies {
			    forward = "none"
			}
		    }
		    viewer_protocol_policy = "allow-all"
		}
		restrictions {
		    geo_restriction {
			restriction_type = "none"
		    }
		}
		viewer_certificate {
		    cloudfront_default_certificate = true
	    }
		connection {
		    type     = "ssh"
		    user     = "ec2-user"
		    private_key = file("${var.ssh_key_name}.pem")
		    host = aws_instance.MyWebServer.public_ip
		}
	    provisioner "remote-exec" {
		inline = [
		    "sudo su << EOF",
		    "echo \"<img src='http://${self.domain_name}/${aws_s3_bucket_object.image_upload.key}' width='500' height='300'>\" >> /var/www/html/index.php",
		    "EOF",	
	       ]
	    }
	}
	```


- **Delete the github repo to get the images to be uploaded to the web page and the public key file**

	```
	resource "null_resource" "delete_downloaded_files" {
	  depends_on = [
		aws_s3_bucket_object.image_upload
	    ]
	  provisioner "local-exec" {
	      when = destroy
	      command = "sudo rm -rvf web_image public-ip.txt"
	  }
	}
	```


- **Print the public IP of the instance created above on the local**

	```
	output "Instance_Public_IP" {
		value = aws_instance.MyWebServer.public_ip
	}
	```
- **To initialize the terraform**

  - `$ terraform init`

- **To run the terraform configuration file for creating the complete infrastructure**

  `- $ terraform apply -auto-approve`
     - after successfully runnning the above command we will see the below message:
        ```
        Apply complete! Resources: 13 added, 0 changed, 0 destroyed.

        Outputs:

        Instance_Public_IP = 13.126.246.125
        ```
- When we run the **13.126.246.125** on the browser

  ![alt text](https://github.com/rasrivastava/task1_hybrid_multi_cloud/blob/master/mm1.png)
  
  ![alt text](https://github.com/rasrivastava/task1_hybrid_multi_cloud/blob/master/mm2.png)

- **To destry the complete infrastructue, we can run below command**

  `$ terraform destroy -auto-approve`
