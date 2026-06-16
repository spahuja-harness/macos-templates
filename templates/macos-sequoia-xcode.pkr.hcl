packer {
  required_plugins {
    tart = {
      version = ">= 1.12.0"
      source  = "github.com/cirruslabs/tart"
    }
  }
}

variable "base_image" {
  type        = string
  description = "Harness base image to build on top of"
  default     = "registry-1.docker.io/harness/macos-vm-images:base_sequoia_15.6.1"
}

variable "vm_name" {
  type        = string
  description = "Name for the output VM"
  default     = "sequoia-xcodes"
}

variable "xcode_version" {
  type        = list(string)
  description = "Xcode versions to install (first one becomes default)"
  default     = ["16.4", "16.3"]
}

variable "xcode_cache_dir" {
  type        = string
  description = "Path to directory containing Xcode xip files"
  default     = "~/XcodesCache"
}

variable "ssh_username" {
  type      = string
  sensitive = true
  default   = "anka"
}

variable "ssh_password" {
  type        = string
  sensitive   = true
  description = "SSH password for the VM (contact support for Harness base image credentials)"
}

variable "push_to_registry" {
  type        = bool
  description = "Whether to push the built image to a registry"
  default     = false
}

variable "registry_image" {
  type        = string
  description = "Full registry path to push (e.g. registry-1.docker.io/org/repo:tag)"
  default     = ""
}

source "tart-cli" "tart" {
  vm_base_name       = var.base_image
  vm_name            = var.vm_name
  cpu_count          = 6
  memory_gb          = 12
  disk_size_gb       = 350
  ssh_password       = var.ssh_password
  ssh_username       = var.ssh_username
  ssh_timeout        = "180s"
  create_grace_time  = "120s"
  recovery_partition = "keep"
}

locals {
  xcode_install_provisioners = [
    for version in reverse(sort(var.xcode_version)) : {
      inline = [
        "source ~/.bash_profile",
        "echo '[INFO] Installing Xcode ${version}...'",
        "sudo xcodes install ${version} --experimental-unxip --path /Users/${var.ssh_username}/Downloads/Xcode_${version}.xip --select --empty-trash",
        "INSTALLED_PATH=$(xcodes select -p)",
        "CONTENTS_DIR=$(dirname $INSTALLED_PATH)",
        "APP_DIR=$(dirname $CONTENTS_DIR)",
        "sudo mv $APP_DIR /Applications/Xcode_${version}.app",
        "sudo xcode-select -s /Applications/Xcode_${version}.app",
        "xcodebuild -runFirstLaunch",
        "echo '[SUCCESS] Xcode ${version} installed'",
      ]
    }
  ]
}

build {
  sources = ["source.tart-cli.tart"]

  # Copy Xcode xip files into the VM
  provisioner "file" {
    sources     = [for version in var.xcode_version : pathexpand("${var.xcode_cache_dir}/Xcode_${version}.xip")]
    destination = "/Users/${var.ssh_username}/Downloads/"
  }

  # Install each Xcode version
  dynamic "provisioner" {
    for_each = local.xcode_install_provisioners
    labels   = ["shell"]
    content {
      inline = provisioner.value.inline
    }
  }

  # Set default Xcode
  provisioner "shell" {
    inline = [
      "source ~/.bash_profile",
      "sudo xcodes select '${var.xcode_version[0]}'",
      "xcodebuild -version",
    ]
  }

  # Validate
  provisioner "shell" {
    inline = [
      "echo '=== Installed Xcode Versions ==='",
      "for app in /Applications/Xcode_*.app; do [ -d \"$app\" ] || continue; ver=$(defaults read \"$app/Contents/version.plist\" CFBundleShortVersionString 2>/dev/null || echo unknown); echo \"  $(basename $app): $ver\"; done",
      "echo ''",
      "echo '=== Default Xcode ==='",
      "xcode-select -p",
      "xcodebuild -version",
      "echo ''",
      "echo '=== Swift ==='",
      "swift --version",
    ]
  }

  # Clean up xips inside VM
  provisioner "shell" {
    inline = [
      "rm -rf /Users/${var.ssh_username}/Downloads/Xcode_*.xip",
    ]
  }

  # Conditionally push to registry
  post-processor "shell-local" {
    inline = concat(
      var.push_to_registry && var.registry_image != "" ? [
        "tart push ${var.vm_name} ${var.registry_image}",
        "echo '[SUCCESS] Pushed to ${var.registry_image}'"
      ] : [
        "echo '[INFO] Push disabled — image available locally as: ${var.vm_name}'"
      ]
    )
  }
}
