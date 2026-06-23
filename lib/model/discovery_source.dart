/// The protocol/method by which a device was discovered. Surfaced in the UI as
/// "discovered-by" mini-icons on each row.
enum DiscoverySource {
  tcp,
  icmp,
  arp,
  mdns,
  bonjour,
  netbios,
  ssdp,
}

/// A best-effort classification of what kind of device a host is.
enum DeviceType {
  router,
  computer,
  laptop,
  phone,
  tablet,
  printer,
  tv,
  speaker,
  camera,
  nas,
  server,
  iot,
  unknown,
}
