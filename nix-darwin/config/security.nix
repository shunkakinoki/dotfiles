{
  # No NOPASSWD: with it, any agent process could sudo past the iron-proxy pf
  # rules. Touch ID keeps interactive sudo cheap.
  security.pam.services.sudo_local.touchIdAuth = true;
}
