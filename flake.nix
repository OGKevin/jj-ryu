{
  description = "Stacked PRs CLI for Jujutsu (jj) with GitHub/GitLab support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      rust-overlay,
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      nixpkgsFor = forAllSystems (
        system:
        import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ];
        }
      );
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgsFor.${system};

          # Use Rust 1.89 stable as specified in Cargo.toml
          rustToolchain = pkgs.rust-bin.stable."1.89.0".default;

          rustPlatform = pkgs.makeRustPlatform {
            cargo = rustToolchain;
            rustc = rustToolchain;
          };
        in
        {
          default = self.packages.${system}.jj-ryu;

          jj-ryu = rustPlatform.buildRustPackage {
            pname = "jj-ryu";
            version = "0.0.1-alpha.11";

            src = ./.;

            cargoHash = "sha256-OD1DpV4s6tgOnDEAfJWScdSKqtYArbqIJVClOtUCYa4=";

            nativeBuildInputs = with pkgs; [
              pkg-config
            ];

            buildInputs =
              with pkgs;
              [
                libgit2
                openssl
                zlib
              ]
              ++ lib.optionals stdenv.hostPlatform.isDarwin [
                curl
                libiconv
              ];

            # Disable vendored libraries - use system versions
            env = {
              LIBGIT2_NO_VENDOR = 1;
              OPENSSL_NO_VENDOR = 1;
            };

            # Integration tests require jj binary
            nativeCheckInputs = with pkgs; [
              git
              jujutsu
            ];

            # Some integration tests need a real git/jj environment
            # Skip them in sandbox, run with: cargo test --lib
            checkFlags = [
              # These tests require jj workspace initialization which fails in sandbox
              "--skip=common::temp_repo::tests::"
              "--skip=test_all_prs_exist_correct_bases"
              "--skip=test_constraint_display_formatting"
              "--skip=test_constraints_skip_synced_bookmarks"
              "--skip=test_create_order_respects_stack_for_comment_linking"
              "--skip=test_draft_pr_in_stack"
              "--skip=test_partial_existing_prs_mixed_operations"
              "--skip=test_push_before_create_constraint"
              "--skip=test_push_before_retarget_constraint"
              "--skip=test_push_order_follows_stack_structure"
              "--skip=test_swap_scenario_retarget_before_push"
              "--skip=test_ten_level_stack_ordering"
              "--skip=test_three_level_swap_middle_to_root"
            ];

            meta = {
              description = "Stacked PRs CLI for Jujutsu with GitHub/GitLab support";
              homepage = "https://github.com/dmmulroy/jj-ryu";
              changelog = "https://github.com/dmmulroy/jj-ryu/releases";
              license = pkgs.lib.licenses.mit;
              maintainers = [ ];
              mainProgram = "ryu";
            };
          };
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.jj-ryu}/bin/ryu";
        };
      });

      # Overlay for use in other flakes
      overlays.default = final: prev: {
        jj-ryu = self.packages.${prev.system}.jj-ryu;
      };
    };
}
