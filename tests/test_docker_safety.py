from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class DockerSafetyTests(unittest.TestCase):
    def test_image_never_copies_the_whole_repository(self) -> None:
        dockerfile = (ROOT / "Dockerfile").read_text(encoding="utf-8")
        self.assertNotIn("COPY . /app", dockerfile)
        self.assertIn("COPY --chown=nighty:nighty scripts/", dockerfile)

    def test_sensitive_paths_are_excluded_from_context(self) -> None:
        ignore = (ROOT / ".dockerignore").read_text(encoding="utf-8")
        self.assertTrue(ignore.startswith("#"))
        self.assertIn("\n*\n", ignore)
        self.assertNotIn("!Nighty.exe", ignore)
        self.assertNotIn("!data/", ignore)
        self.assertNotIn("!docker-secrets/", ignore)

    def test_compose_uses_secret_files_without_default_credentials(self) -> None:
        compose = (ROOT / "docker-compose.yml").read_text(encoding="utf-8")
        self.assertNotIn("WEBUI_USERNAME=admin", compose)
        self.assertNotIn("WEBUI_PASSWORD=secret", compose)
        self.assertIn("./docker-secrets/webui_username", compose)
        self.assertIn("./docker-secrets/webui_password", compose)

    def test_arm_runtime_invokes_wine_through_box64(self) -> None:
        launcher = (ROOT / "scripts" / "wine_command.sh").read_text(encoding="utf-8")
        run_script = (ROOT / "scripts" / "run.sh").read_text(encoding="utf-8")
        self.assertIn('NIGHTY_WINE_COMMAND=("$box64_bin" "$wine_bin")', launcher)
        self.assertIn('"${NIGHTY_WINE_COMMAND[@]}" "$NIGHTY_STUB"', run_script)

    def test_runtime_has_a_webui_port_default_without_env_file(self) -> None:
        run_script = (ROOT / "scripts" / "run.sh").read_text(encoding="utf-8")
        self.assertIn(': "${WEBUI_PORT:=8090}"', run_script)

    def test_native_webui_stays_private_behind_the_bridge(self) -> None:
        dockerfile = (ROOT / "Dockerfile").read_text(encoding="utf-8")
        self.assertIn("ENV WEBUI_HOST=127.0.0.1", dockerfile)
        self.assertIn("BRIDGE_HOST=0.0.0.0", dockerfile)
        self.assertNotIn("ENV WEBUI_HOST=0.0.0.0", dockerfile)

    def test_box64_build_is_pinned_to_the_validated_revision(self) -> None:
        dockerfile = (ROOT / "Dockerfile").read_text(encoding="utf-8")
        self.assertIn("c01888938978d85938205ac761327081d58d6ffd", dockerfile)
        self.assertIn("box64/archive/${BOX64_VERSION}.tar.gz", dockerfile)

    def test_box64_is_available_at_the_host_binfmt_path(self) -> None:
        dockerfile = (ROOT / "Dockerfile").read_text(encoding="utf-8")
        self.assertIn("ln -sf /usr/local/bin/box64 /usr/bin/box64", dockerfile)
        self.assertIn("test -x /usr/bin/box64", dockerfile)


if __name__ == "__main__":
    unittest.main()
