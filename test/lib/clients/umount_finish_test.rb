#!/usr/bin/env rspec

require_relative "../../test_helper"
require "installation/clients/umount_finish"

describe Yast::UmountFinishClient do
  subject(:client) { described_class.new }

  DEFAULT_SUBVOLUME = "@/.snapshots/1/snapshot".freeze

  describe "#set_btrfs_defaults_as_ro" do
    before do
      allow(Yast::Execute).to receive(:on_target)
        .with("btrfs", "subvolume", "get-default", "/", anything)
        .and_return(get_default)
      allow(Y2Storage::StorageManager.instance).to receive(:staging).and_return(devicegraph)
    end

    let(:devicegraph) do
      instance_double(Y2Storage::Devicegraph, filesystems: [root_fs])
    end

    let(:root_fs) do
      instance_double(
        Y2Storage::Filesystems::Btrfs,
        is?:               true,
        mount_point:       mount_point,
        mount_options:     mount_options,
        subvolumes_prefix: subvolumes_prefix
      )
    end

    let(:mount_point) { instance_double(Y2Storage::MountPoint, path: "/") }
    let(:mount_options) { ["ro"] }
    let(:subvolumes_prefix) { "@" }
    let(:get_default) { "ID 276 gen 1172 top level 275 path @/.snapshots/1/snapshot\n" }

    context "when a Btrfs filesystem is mounted as read-only" do
      context "and there is no subvolume_prefix" do
        let(:subvolumes_prefix) { "" }

        context "and snapshots are enabled" do
          let(:get_default) { "ID 276 gen 1172 top level 275 path .snapshots/1/snapshot\n" }

          it "sets 'ro' property to true on the snapshot" do
            expect(root_fs).to receive(:btrfs_subvolume_mount_point)
              .with(".snapshots/1/snapshot").and_return("/.snapshots/1/snapshot")
            expect(Yast::Execute).to receive(:on_target)
              .with("btrfs", "property", "set", "/.snapshots/1/snapshot", "ro", "true")
            client.set_btrfs_defaults_as_ro
          end
        end

        context "and snapshots are disabled" do
          let(:get_default) { "ID 5 (FS_TREE)\n" }

          it "sets 'ro' property to true on the mount point" do
            expect(root_fs).to receive(:btrfs_subvolume_mount_point)
              .with("").and_return("/")
            expect(Yast::Execute).to receive(:on_target)
              .with("btrfs", "property", "set", "/", "ro", "true")
            client.set_btrfs_defaults_as_ro
          end
        end
      end

      context "and there is a subvolume_prefix" do
        let(:subvolumes_prefix) { "@" }

        context "and snapshots are enabled" do
          let(:get_default) { "ID 276 gen 1172 top level 275 path @/.snapshots/1/snapshot\n" }

          it "sets 'ro' property to true on the snapshot" do
            expect(root_fs).to receive(:btrfs_subvolume_mount_point)
              .with("@/.snapshots/1/snapshot").and_return("/.snapshots/1/snapshot")
            expect(Yast::Execute).to receive(:on_target)
              .with("btrfs", "property", "set", "/.snapshots/1/snapshot", "ro", "true")
            client.set_btrfs_defaults_as_ro
          end
        end

        context "and snapshots are disabled" do
          let(:get_default) { "ID 276 gen 1172 top level 275 path @\n" }

          it "sets 'ro' property to true on the mount point" do
            expect(root_fs).to receive(:btrfs_subvolume_mount_point)
              .with("@").and_return("/")
            expect(Yast::Execute).to receive(:on_target)
              .with("btrfs", "property", "set", "/", "ro", "true")
            client.set_btrfs_defaults_as_ro
          end
        end
      end

      context "mount point is different than root" do
        let(:mount_point) { instance_double(Y2Storage::MountPoint, path: "/home") }
        let(:subvolumes_prefix) { "" }

        before do
          allow(Yast::Execute).to receive(:on_target)
            .with("btrfs", "subvolume", "get-default", "/home", anything)
            .and_return("ID 5 (FS_TREE)\n")
        end

        it "sets 'ro' property to true on the mount point" do
          expect(root_fs).to receive(:btrfs_subvolume_mount_point)
            .with("").and_return("/home")
          expect(Yast::Execute).to receive(:on_target)
            .with("btrfs", "property", "set", "/home", "ro", "true")
          client.set_btrfs_defaults_as_ro
        end
      end
    end

    context "when a non-Btrfs filesystem is mounted" do
      let(:root_fs) { instance_double(Y2Storage::Filesystems::Base, is?: false) }

      it "does not try to set 'ro' property for that filesystem" do
        expect(Yast::Execute).to_not receive(:on_target)
          .with("btrfs", "property", "set", any_args)
        client.set_btrfs_defaults_as_ro
      end
    end

    context "when Btrfs filesystem is not mounted as read-only" do
      let(:mount_options) { [] }

      it "does not try to set 'ro' property" do
        expect(Yast::Execute).to_not receive(:on_target)
          .with("btrfs", "property", "set", any_args)
        client.set_btrfs_defaults_as_ro
      end
    end
  end
end
