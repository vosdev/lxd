test_tls_restrictions() {
  ensure_import_testimage
  ensure_has_localhost_remote "${LXD_ADDR}"

  FINGERPRINT=$(lxc config trust list --format csv | cut -d, -f4)

  # Validate admin rights with no restrictions
  lxc_remote project create localhost:blah

  # Validate normal view with no restrictions
  lxc_remote project list localhost: | grep -q default
  lxc_remote project list localhost: | grep -q blah

  # Apply restrictions
  lxc config trust show "${FINGERPRINT}" | sed -e "s/restricted: false/restricted: true/" | lxc config trust edit "${FINGERPRINT}"

  # Confirm no project visible when none listed
  [ "$(lxc_remote project list localhost: --format csv | wc -l)" = 0 ]

  # Allow access to project blah
  lxc config trust show "${FINGERPRINT}" | sed -e "s/projects: \[\]/projects: ['blah']/" -e "s/restricted: false/restricted: true/" | lxc config trust edit "${FINGERPRINT}"

  # Validate restricted view
  ! lxc_remote project list localhost: | grep -q default || false
  lxc_remote project list localhost: | grep -q blah

  ! lxc_remote project create localhost:blah1 || false

  # Cleanup
  lxc config trust show "${FINGERPRINT}" | sed -e "s/restricted: true/restricted: false/" | lxc config trust edit "${FINGERPRINT}"
  lxc project delete blah
}

test_certificate_edit() {
  if [ ! -d "/usr/share/easy-rsa/" ]; then
    echo "==> SKIP: The certificate_edit test requires easy-rsa to be installed"
    return
  fi

  # Setup the PKI.
  PKI_DIR=$(mktemp -d -p "${TEST_DIR}" XXX)
  cp -R /usr/share/easy-rsa/* "${PKI_DIR}"
  (
    set -e
    cd "${PKI_DIR}"
    # shellcheck disable=SC1091
    if [ -e pkitool ]; then
        . ./vars
        ./clean-all
        ./pkitool --initca
        ./pkitool lxd-client
    else
        ./easyrsa init-pki
        echo "lxd" | ./easyrsa build-ca nopass
        ./easyrsa build-client-full lxd-client nopass
        mkdir keys
        cp pki/private/* keys/
        cp pki/issued/* keys/
        cp pki/ca.crt keys/
    fi
  )

  ensure_import_testimage
  ensure_has_localhost_remote "${LXD_ADDR}"

  FINGERPRINT=$(lxc config trust list --format csv | cut -d, -f4)

  # Try replacing the own certificate with a new one.
  # This should succeed as the user is listed as an admin.
  curl -k -s --cert "${LXD_CONF}/client.crt" --key "${LXD_CONF}/client.key" -X PATCH -d "{\"certificate\":\"$(sed ':a;N;$!ba;s/\n/\\n/g' "${PKI_DIR}/keys/lxd-client.crt")\"}" "https://${LXD_ADDR}/1.0/certificates/${FINGERPRINT}"

  # Record new fingerprint
  FINGERPRINT=$(lxc config trust list --format csv | cut -d, -f4)

  # Move new certificate and key to LXD_CONF and back up old files.
  mv "${LXD_CONF}/client.crt" "${LXD_CONF}/client.crt.bak"
  mv "${LXD_CONF}/client.key" "${LXD_CONF}/client.key.bak"
  mv "${PKI_DIR}/keys/lxd-client.crt" "${LXD_CONF}/client.crt"
  mv "${PKI_DIR}/keys/lxd-client.key" "${LXD_CONF}/client.key"

  lxc_remote project create localhost:blah

  # Apply restrictions
  lxc config trust show "${FINGERPRINT}" | sed -e "s/restricted: false/restricted: true/" | lxc config trust edit "${FINGERPRINT}"

  # Add created project to the list of restricted projects. This way, the user will be listed as
  # a normal user instead of an admin.
  lxc config trust show "${FINGERPRINT}" | sed -e "s/projects: \[\]/projects: \[blah\]/" | lxc config trust edit "${FINGERPRINT}"

  # Try replacing the own certificate with the old one.
  # This should succeed as well as the own certificate may be changed.
  curl -k -s --cert "${LXD_CONF}/client.crt" --key "${LXD_CONF}/client.key" -X PATCH -d "{\"certificate\":\"$(sed ':a;N;$!ba;s/\n/\\n/g' "${LXD_CONF}/client.crt.bak")\"}" "https://${LXD_ADDR}/1.0/certificates/${FINGERPRINT}"

  # Move new certificate and key to LXD_CONF and back up old ones.
  mv "${LXD_CONF}/client.crt.bak" "${LXD_CONF}/client.crt"
  mv "${LXD_CONF}/client.key.bak" "${LXD_CONF}/client.key"

  # Record new fingerprint
  FINGERPRINT=$(lxc config trust list --format csv | cut -d, -f4)

  # Trying to change other fields should fail as a non-admin.
  ! lxc_remote config trust show "${FINGERPRINT}" | sed -e "s/restricted: true/restricted: false/" | lxc_remote config trust edit localhost:"${FINGERPRINT}" || false

  curl -k -s --cert "${LXD_CONF}/client.crt" --key "${LXD_CONF}/client.key" -X PATCH -d "{\"restricted\": false}" "https://${LXD_ADDR}/1.0/certificates/${FINGERPRINT}"

  ! lxc_remote config trust show "${FINGERPRINT}" | sed -e "s/name:.*/name: foo/" | lxc_remote config trust edit localhost:"${FINGERPRINT}" || false

  curl -k -s --cert "${LXD_CONF}/client.crt" --key "${LXD_CONF}/client.key" -X PATCH -d "{\"name\": \"bar\"}" "https://${LXD_ADDR}/1.0/certificates/${FINGERPRINT}"

  ! lxc_remote config trust show "${FINGERPRINT}" | sed -e ':a;N;$!ba;s/projects:\n- blah/projects: \[\]/' | lxc_remote config trust edit localhost:"${FINGERPRINT}" || false

  curl -k -s --cert "${LXD_CONF}/client.crt" --key "${LXD_CONF}/client.key" -X PATCH -d "{\"projects\": []}" "https://${LXD_ADDR}/1.0/certificates/${FINGERPRINT}"

  # Cleanup
  lxc config trust show "${FINGERPRINT}" | sed -e "s/restricted: true/restricted: false/" | lxc config trust edit "${FINGERPRINT}"

  lxc config trust show "${FINGERPRINT}" | sed -e ':a;N;$!ba;s/projects:\n- blah/projects: \[\]/' | lxc config trust edit "${FINGERPRINT}"

  lxc project delete blah
}
