# Only concrete SSH aliases can also be shell commands. A Host entry may list
# several names, while wildcard and negated patterns must remain SSH-only.
settings:
let
  patterns = builtins.concatMap (
    key:
    let
      block = settings.${key};
      data = block.data or block;
      header = data.header or "Host ${key}";
      host = builtins.match "[Hh][Oo][Ss][Tt][[:space:]]+(.+)" header;
    in
    if host == null then
      [ ]
    else
      builtins.filter builtins.isString (builtins.split "[[:space:]]+" (builtins.head host))
  ) (builtins.attrNames settings);
  names = builtins.filter (name: builtins.match "[a-zA-Z0-9_][a-zA-Z0-9_.-]*" name != null) patterns;
in
builtins.listToAttrs (
  map (name: {
    inherit name;
    value = "ssh ${name}";
  }) names
)
