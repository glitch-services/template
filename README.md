# Example Glitch Service

To create a service, place service source code in the `service` directory.  This must include a docker-compose.yaml file to start the service.

Place the checker in the `checker` directory, with a `checker.py` file that defines `check(host)`, `put(host, flag, flag_id):`, and `get(host, flag, flag_id, private)` functions.

Finally, modify `service.yaml` to include the service name and ports. Note: do not use common ports like 8080 or 1337 - use random 4-digits ports only to avoid conflicts with other services.
In the `service.yaml`, list all ports that will be exposed by the service, and specify the protocol of the port (http, https, or tcp) - this will be used to automatically set up network monitoring tools on the vulnbox.

To test, run `bash test.sh`, which will start the service, test the checker, and run any exploits you have added.

