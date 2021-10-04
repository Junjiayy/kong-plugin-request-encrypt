package = "kong-plugin-request-encrypt"
version = "0.1.0"
supported_platforms = {"linux", "macosx"}
source = {
  url = "git://github.com/Junjiayy/kong-plugin-request-encrypt",
  tag = "0.1.0"
}

description = {
  summary = "Request-encrypt is a kong plug-in that encrypts requests and responses",
  homepage = "git://github.com/Junjiayy/kong-plugin-request-encrypt",
  license = "MIT"
}

dependencies = {
  "lua >= 5.1, < 5.2",
  "lua-resty-redis == 0.27-0",
  "lua-resty-rsa == 1.1.0-1",
  "luabitop == 1.0.2-3",
}

build = {
  type = "builtin",
  modules = {
    ["kong.plugins.request-encrypt.encrypt"] = "encrypt.lua",
    ["kong.plugins.request-encrypt.access"] = "access.lua",
    ["kong.plugins.request-encrypt.handler"] = "handler.lua",
    ["kong.plugins.request-encrypt.schema"] = "schema.lua",
  }
}
