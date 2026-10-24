# Security

## Credential handling

The campus-network password is required by the ePortal protocol. Keep the real two-line configuration file outside the repository and restrict it to the service owner (`chmod 600`). Never attach it to an Issue or paste it into logs.

The OpenWrt installer reads the password interactively without echoing it and does not place it in command-line arguments. The login program deliberately avoids printing the password, MAC address, or complete portal query string.

## Reporting a vulnerability

Please report a security issue privately through GitHub Security Advisories if that option is available on the repository. Do not include a real student ID, password, session cookie, MAC address, or complete captive-portal URL in the report.
