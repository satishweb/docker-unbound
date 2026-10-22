#!/usr/bin/env python3

import argparse
import os
import re
import shutil
import sys
import tempfile
import time
import unittest

HEALTH_TIMEOUT = 180  # seconds to wait for the container to become healthy
# A domain from the default block list of the image.
BLOCKED_DOMAIN = "www.doubleclick.net"
# A domain that is served from the custom hosts file of the container.
CUSTOM_DOMAIN = "doh-test.example.com"
CUSTOM_ADDRESS = "192.0.2.42"


def install_dependencies():
    missing = []
    for module in ("requests", "docker"):
        try:
            __import__(module)
        except ImportError:
            missing.append(module)
    if missing:
        print(
            "ERROR: missing python module(s): {}. "
            "Install them with: pip install {}".format(", ".join(missing), " ".join(missing)),
            file=sys.stderr,
        )
        sys.exit(1)


def wait_for_container_health(container, timeout=HEALTH_TIMEOUT):
    print("Waiting for the container to be healthy...")
    deadline = time.time() + timeout
    while True:
        container.reload()
        state = container.attrs.get("State", {})
        status = state.get("Health", {}).get("Status")
        if status == "healthy":
            print("The container is healthy.")
            return
        if state.get("Status") in ("exited", "dead"):
            logs = container.logs().decode("utf-8", errors="replace")
            raise RuntimeError(
                f"The container stopped before it became healthy (status={state.get('Status')}).\n{logs}"
            )
        if time.time() > deadline:
            logs = container.logs().decode("utf-8", errors="replace")
            raise RuntimeError(
                f"The container did not become healthy within {timeout}s (last status={status}).\n{logs}"
            )
        time.sleep(2)


def resolve(container, name):
    """Resolve a name with the resolver of the container.

    Returns the address the name resolved to, an empty string when the name
    does not resolve.
    """
    output = container.exec_run(f"drill @127.0.0.1 {name}").output.decode("utf-8", errors="replace")
    for line in output.splitlines():
        # The answer lines look like "name.\t3600\tIN\tA\t192.0.2.42"
        parts = line.split()
        if len(parts) >= 5 and parts[-3] == "IN" and parts[-2] == "A":
            return parts[-1]
    return ""


def run_tests(image_name, port, timeout):
    install_dependencies()

    import docker

    class TestUnboundServer(unittest.TestCase):
        def setUp(self):
            self.client = docker.from_env()
            self.custom_dir = os.path.realpath(
                tempfile.mkdtemp(prefix="unbound-custom-", dir=os.path.expanduser("~"))
            )
            with open(os.path.join(self.custom_dir, "custom.hosts"), "w") as handle:
                # The custom hosts file is a part of the unbound configuration
                handle.write(f'local-zone: "{CUSTOM_DOMAIN}" transparent\n')
                handle.write(f'local-data: "{CUSTOM_DOMAIN} A {CUSTOM_ADDRESS}"\n')
            self.container = self.client.containers.run(
                image_name,
                detach=True,
                environment={
                    "DOMAIN_WHITELIST": "",
                },
                volumes={self.custom_dir: {"bind": "/etc/unbound/custom", "mode": "ro"}},
            )
            # The server needs the block list before it starts to answer, that
            # takes a moment.
            wait_for_container_health(self.container)

        def tearDown(self):
            self.container.stop()
            self.container.remove()
            shutil.rmtree(self.custom_dir, ignore_errors=True)

        def test_healthcheck(self):
            print("Running the health check test...")
            exit_code = self.container.exec_run("/docker-healthcheck").exit_code
            self.assertEqual(exit_code, 0, "The health check script failed")
            print("Health check test passed.")

        def test_custom_hosts(self):
            """A name from the custom hosts file has to resolve."""
            print("Running the custom hosts test...")
            address = resolve(self.container, CUSTOM_DOMAIN)
            self.assertEqual(
                address, CUSTOM_ADDRESS, f"{CUSTOM_DOMAIN} did not resolve to {CUSTOM_ADDRESS}"
            )
            print("Custom hosts test passed.")

        def test_blocked_hosts(self):
            """A name from the block list has to be blocked."""
            print("Running the blocked hosts test...")
            address = resolve(self.container, BLOCKED_DOMAIN)
            self.assertIn(
                address, ("0.0.0.0", "0"), f"{BLOCKED_DOMAIN} was not blocked, it resolved to {address}"
            )
            print("Blocked hosts test passed.")

        def test_secret_is_applied(self):
            """A secret has to be exported and the container has to start."""
            print("Running the secret test...")
            secret_dir = os.path.realpath(
                tempfile.mkdtemp(prefix="unbound-secret-", dir=os.path.expanduser("~"))
            )
            try:
                with open(os.path.join(secret_dir, "DOMAIN_WHITELIST"), "w") as handle:
                    handle.write("example.com\n")
                container = self.client.containers.run(
                    image_name,
                    detach=True,
                    environment={
                        "DOMAIN_WHITELIST_FILE": "/run/secrets/DOMAIN_WHITELIST",
                    },
                    volumes={secret_dir: {"bind": "/run/secrets", "mode": "ro"}},
                )
                try:
                    wait_for_container_health(container)
                    logs = container.logs().decode("utf-8", errors="replace")
                    self.assertIn(
                        "Exporting var: DOMAIN_WHITELIST", logs, "The secret was not exported"
                    )
                finally:
                    container.stop()
                    container.remove()
            finally:
                shutil.rmtree(secret_dir, ignore_errors=True)
            print("Secret test passed.")

    print(f"Starting the container from the image '{image_name}'...")
    client = docker.from_env()
    container = client.containers.run(image_name, detach=True)
    try:
        wait_for_container_health(container)
    finally:
        container.stop()
        container.remove()

    suite = unittest.TestLoader().loadTestsFromTestCase(TestUnboundServer)
    print("Running the tests...")
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    if not result.wasSuccessful():
        sys.exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run the tests for the unbound container image.")
    parser.add_argument("--image", type=str, default="satishweb/unbound-test", help="The image that is tested")
    parser.add_argument("--port", type=str, default="5354", help="The port of the container (default: 5354)")
    parser.add_argument("--timeout", type=str, default="180", help="Seconds to wait for the container (default: 180)")
    args = parser.parse_args()

    run_tests(args.image, args.port, args.timeout)
