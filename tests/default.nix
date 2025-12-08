# Main test runner for bcachefs TPM2 unlocking
{ pkgs, lib, ... }:

let
  # Import all test modules
  testModules = import ./bcachefs-tpm2-unlock.nix { inherit pkgs lib; };
in
{
  # Run all tests as separate NixOS tests
  basicUnlock = testModules.basicUnlock;
  tpmFailureFallback = testModules.tpmFailureFallback;
  fido2Test = testModules.fido2Test;
  performanceTest = testModules.performanceTest;
  
  # Combined test suite for CI
  testSuite = pkgs.symlinkJoin {
    name = "bcachefs-tpm2-test-suite";
    paths = [
      testModules.basicUnlock
      testModules.tpmFailureFallback  
      testModules.fido2Test
      testModules.performanceTest
    ];
  };
  
  # Test configuration for manual testing
  manualTestConfig = {
    imports = [ ./disko/module.nix ];
    
    virtualisation.emptyDiskImages = [ 4096 ];
    
    environment.systemPackages = with pkgs; [
      clevis jose tpm2-tools bcachefs-tools libfido2
      util-linux time
    ];
    
    disko.devices = {
      disk.main = {
        device = "/dev/vdb";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02";
            };
            root = {
              size = "100%";
              content = {
                type = "bcachefs_filesystem";
                name = "nixos-main";
                mountpoint = "/";
                extraFormatArgs = [ "--encrypted" ];
                
                unlock = {
                  enable = true;
                  secretFiles = [
                    ./test-secrets/tpm.jwe
                    ./test-secrets/fido.jwe
                    ./test-secrets/tang.jwe
                  ];
                  extraPackages = with pkgs; [ libfido2 ];
                };
                
                subvolumes = {
                  "root" = { mountpoint = "/"; };
                  "home" = { mountpoint = "/home"; };
                  "nix" = { mountpoint = "/nix"; };
                };
              };
            };
          };
        };
      };
    };
  };
}