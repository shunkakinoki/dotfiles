{
  kyber = [
    {
      name = "openclaw";
      httpsPort = 443;
      localPort = 18789;
      manager = "activation";
    }
    {
      name = "t3";
      httpsPort = 8443;
      localPort = 3773;
      manager = "t3-service";
    }
    {
      name = "hermes";
      httpsPort = 9443;
      localPort = 9120;
      manager = "activation";
    }
    {
      name = "crabbox";
      httpsPort = 10443;
      localPort = 18080;
      manager = "activation";
    }
  ];

  matic = [
    {
      name = "t3";
      httpsPort = 443;
      localPort = 3773;
      manager = "activation";
    }
  ];
}
